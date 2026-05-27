import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/gradients.dart';
import '../../../core/design/responsive.dart';
import '../../../core/models/parish_profile.dart';
import '../../../core/services/firebase_service.dart';
import '../../../features/sacraments/screens/sacrament_form_screen.dart';
import '../../../shared/widgets/welcome_banner.dart';
import '../../../shared/widgets/sacrament_card.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final bool isTagalog;
  final bool isGuest;
  final void Function(SacramentType) onSacramentTap;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.onSacramentTap,
    this.isTagalog = true,
    this.isGuest = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<MassScheduleItem> _parishMassSchedule = [];
  List<OfficeScheduleItem> _parishOfficeSchedule = [];
  Map<DateTime, List<dynamic>> _massSchedules = {};
  Map<DateTime, List<dynamic>> _userBookings = {};
  bool _isLoading = true;
  DateTime? _userBirthday;
  int? _userAge;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    if (!widget.isGuest) {
      _loadCalendarData();
      _loadUserBirthday();
    } else {
      _isLoading = false;
    }
  }

  /// Fetch user's birthday from Firestore
  Future<void> _loadUserBirthday() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (userDoc.docs.isNotEmpty) {
        final data = userDoc.docs.first.data();
        final birthdayData = data['birthday'];

        if (birthdayData != null) {
          DateTime birthday;
          if (birthdayData is Timestamp) {
            birthday = birthdayData.toDate();
          } else if (birthdayData is DateTime) {
            birthday = birthdayData;
          } else if (birthdayData is String) {
            birthday = DateTime.tryParse(birthdayData) ?? DateTime.now();
          } else {
            return;
          }

          setState(() {
            _userBirthday = birthday;
            _userAge = _calculateAge(birthday);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user birthday: $e');
    }
  }

  /// Calculate age from birthday
  int _calculateAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  /// Check if a sacrament should be available based on age
  bool _isSacramentAvailable(SacramentType type) {
    if (widget.isGuest) return true;
    if (_userAge == null) return true; // Allow if age not loaded

    // Hide all sacraments for users under 18
    if (_userAge! < 18) return false;

    // Hide Wedding for ages 18-20
    if (type == SacramentType.wedding && _userAge! < 21) {
      return false;
    }

    // Allow all others
    return true;
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _matchesMassScheduleDay(DateTime day, MassScheduleItem item) {
    final englishDay = item.englishDay.toLowerCase().trim();
    final tagalogDay = item.tagalogDay.toLowerCase().trim();
    final dayText = ('$englishDay $tagalogDay').trim();

    final weekdayNames = {
      DateTime.monday: ['monday', 'lunes'],
      DateTime.tuesday: ['tuesday', 'martes'],
      DateTime.wednesday: ['wednesday', 'miyerkules', 'miercoles'],
      DateTime.thursday: ['thursday', 'huwebes'],
      DateTime.friday: ['friday', 'biyernes'],
      DateTime.saturday: ['saturday', 'sabado'],
      DateTime.sunday: ['sunday', 'linggo', 'domingo'],
    };

    int weekdayOfLabel(String token) {
      final t = token.toLowerCase();
      for (final entry in weekdayNames.entries) {
        if (entry.value.any((n) => t.contains(n))) return entry.key;
      }
      return -1;
    }

    // If item explicitly labeled as Sunday, only show on Sundays
    if (item.category == MassCategory.sunday) {
      return day.weekday == DateTime.sunday;
    }

    // Look for explicit weekday ranges like "Tue-Fri" or single weekday mentions
    final rangeRegex = RegExp(r'([a-zA-Z]{3,9})\s*[-–—]\s*([a-zA-Z]{3,9})');
    final rangeMatch = rangeRegex.firstMatch(dayText);
    if (rangeMatch != null) {
      final a = rangeMatch.group(1) ?? '';
      final b = rangeMatch.group(2) ?? '';
      final ai = weekdayOfLabel(a);
      final bi = weekdayOfLabel(b);
      if (ai != -1 && bi != -1) {
        final w = day.weekday;
        if (ai <= bi) {
          return w >= ai && w <= bi;
        }
        return w >= ai || w <= bi;
      }
    }

    // If specific weekdays are mentioned (e.g., "Tuesday"), only show on those days
    for (final entry in weekdayNames.entries) {
      if (entry.value.any((n) => dayText.contains(n))) {
        return day.weekday == entry.key;
      }
    }

    // For daily items, support keywords like 'weekday', 'daily', 'every day'
    if (item.category == MassCategory.daily) {
      if (dayText.contains('weekday') || dayText.contains('weekdays')) {
        return day.weekday >= DateTime.monday && day.weekday <= DateTime.friday;
      }
      if (dayText.contains('daily') ||
          dayText.contains('araw-araw') ||
          dayText.contains('every day')) {
        final hasSundaySchedule = _parishMassSchedule.any(
          (s) => s.category == MassCategory.sunday,
        );
        if (day.weekday == DateTime.sunday && hasSundaySchedule) return false;
        return true;
      }

      // Default daily behavior: show on all non-Sunday days unless there's a Sunday schedule
      final hasSundaySchedule = _parishMassSchedule.any(
        (s) => s.category == MassCategory.sunday,
      );
      if (day.weekday == DateTime.sunday && hasSundaySchedule) return false;
      return true;
    }

    return false;
  }

  bool _matchesOfficeScheduleDay(DateTime day, OfficeScheduleItem item) {
    final label =
        (item.englishLabel.isNotEmpty ? item.englishLabel : item.tagalogLabel)
            .toLowerCase()
            .trim();

    final weekdayNames = {
      DateTime.monday: ['monday', 'mon'],
      DateTime.tuesday: ['tuesday', 'tue', 'tues'],
      DateTime.wednesday: ['wednesday', 'wed'],
      DateTime.thursday: ['thursday', 'thu', 'thurs'],
      DateTime.friday: ['friday', 'fri'],
      DateTime.saturday: ['saturday', 'sat'],
      DateTime.sunday: ['sunday', 'sun'],
    };

    int? weekdayFromToken(String token) {
      for (final entry in weekdayNames.entries) {
        if (entry.value.contains(token)) {
          return entry.key;
        }
      }
      return null;
    }

    final rangeRegex = RegExp(
      r'\b(mon|monday|tue|tues|tuesday|wed|wednesday|thu|thurs|thursday|fri|friday|sat|saturday|sun|sunday)\s*(?:-|to|–|—)\s*(mon|monday|tue|tues|tuesday|wed|wednesday|thu|thurs|thursday|fri|friday|sat|saturday|sun|sunday)\b',
      caseSensitive: false,
    );

    final rangeMatch = rangeRegex.firstMatch(label);
    if (rangeMatch != null) {
      final start = weekdayFromToken(rangeMatch.group(1)!.toLowerCase());
      final end = weekdayFromToken(rangeMatch.group(2)!.toLowerCase());
      if (start != null && end != null) {
        var current = start;
        while (true) {
          if (current == day.weekday) return true;
          if (current == end) break;
          current = current == DateTime.sunday ? DateTime.monday : current + 1;
        }
      }
    }

    for (final entry in weekdayNames.entries) {
      if (entry.value.any((term) => label.contains(term))) {
        return day.weekday == entry.key;
      }
    }

    if (label.contains('weekday') || label.contains('weekdays')) {
      return day.weekday >= DateTime.monday && day.weekday <= DateTime.friday;
    }

    if (label.contains('daily') ||
        label.contains('every day') ||
        label.contains('araw-araw')) {
      return true;
    }

    return false;
  }

  Widget _buildEventMarkers(
    BuildContext context,
    DateTime day,
    List<dynamic> events,
  ) {
    final markerWidgets = <Widget>[];
    if (events.any((event) => event['type'] == 'booking')) {
      markerWidgets.add(
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: const BoxDecoration(
            color: ParishColors.primaryGold,
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    if (markerWidgets.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: markerWidgets,
    );
  }

  Widget _buildDayBuilder(
    BuildContext context,
    DateTime day,
    DateTime focusedDay,
  ) {
    final events = _getEventsForDay(day);
    final isSelected = _selectedDay != null && isSameDay(_selectedDay, day);
    final isToday = isSameDay(day, DateTime.now());

    final dayDecoration = BoxDecoration(
      color: Colors.transparent,
      border: isSelected
          ? Border.all(color: ParishColors.primaryBlue, width: 2)
          : null,
      shape: BoxShape.circle,
    );

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: dayDecoration,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              color: ParishColors.textBlue900,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _buildEventMarkers(context, day, events),
        ],
      ),
    );
  }

  String t(String tagalog, String english) =>
      widget.isTagalog ? tagalog : english;

  Future<void> _loadCalendarData() async {
    if (widget.isGuest) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    setState(() => _isLoading = true);
    await _loadUserBookings();
    setState(() => _isLoading = false);
  }

  Future<void> _loadMassSchedules() async {
    try {
      final parishProfile = await FirebaseService.instance.getParishProfile();
      if (parishProfile != null) {
        if (parishProfile.massSchedule.isNotEmpty) {
          setState(() => _parishMassSchedule = parishProfile.massSchedule);
        }
        if (parishProfile.officeSchedule.isNotEmpty) {
          setState(() => _parishOfficeSchedule = parishProfile.officeSchedule);
        }
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('mass_schedules')
          .get();

      final schedules = <DateTime, List<dynamic>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            final normalizedDate = _normalizeDate(date);
            schedules.putIfAbsent(normalizedDate, () => []);
            schedules[normalizedDate]!.add({
              'id': doc.id,
              'type': 'mass',
              'time': normalizeSimpleTime(
                data['time'] ?? data['timeString'] ?? '',
              ),
              'title': data['title'] ?? t('Misa', 'Mass'),
              'description': data['description'] ?? '',
            });
          }
        }
      }
      setState(() => _massSchedules = schedules);
    } catch (e) {
      debugPrint('Error loading mass schedules: $e');
    }
  }

  Future<void> _loadUserBookings() async {
    try {
      if (widget.isGuest) return;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      final bookings = <DateTime, List<dynamic>>{};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            final normalizedDate = DateTime(date.year, date.month, date.day);
            bookings.putIfAbsent(normalizedDate, () => []);
            bookings[normalizedDate]!.add({
              'id': doc.id,
              'type': 'booking',
              'time': data['time'] ?? '',
              'title': data['sacramentType'] ?? t('Booking', 'Booking'),
              'status': data['status'] ?? 'pending',
            });
          }
        }
      }
      setState(() => _userBookings = bookings);
    } catch (e) {
      debugPrint('Error loading user bookings: $e');
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final normalizedDate = _normalizeDate(day);
    final events = <dynamic>[];

    if (false) {
      events.addAll(
      _parishOfficeSchedule
          .where((item) => _matchesOfficeScheduleDay(day, item))
          .map((item) {
            final normalized = normalizeSimpleTime(item.time);
            final officeTitle = item.label(widget.isTagalog).isNotEmpty
                ? item.label(widget.isTagalog)
                : t('Oras ng opisina', 'Office hours');
            final officeDescription = item.description.isNotEmpty
                ? item.description
                : '$officeTitle · ${t('Office is open from', 'Office is open from')} $normalized';
            return {
              'type': 'office_hours',
              'title': officeTitle,
              'time': normalized,
              'description': officeDescription,
            };
          }),
      );
    }

    events.addAll(_userBookings[normalizedDate] ?? []);

    final dedupedEvents = <dynamic>[];
    final seenKeys = <String>{};
    for (var event in events) {
      final key =
          '${event['type'] ?? ''}|${event['title'] ?? ''}|${event['time'] ?? ''}|${event['description'] ?? ''}|${event['id'] ?? ''}';
      if (seenKeys.add(key)) {
        dedupedEvents.add(event);
      }
    }

    return dedupedEvents;
  }

  void _showEventDetails(dynamic event) {
    final isBooking = event['type'] == 'booking';
    final isOfficeClosed = event['type'] == 'office_closed';
    final isOfficeHours = event['type'] == 'office_hours';
    final status = event['status'] as String? ?? 'pending';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isBooking
                  ? Icons.bookmark
                  : isOfficeClosed
                  ? Icons.business
                  : isOfficeHours
                  ? Icons.work
                  : Icons.church,
              color: isBooking
                  ? ParishColors.primaryGold
                  : isOfficeClosed
                  ? Colors.black87
                  : isOfficeHours
                  ? ParishColors.grayDark
                  : ParishColors.primaryBlue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                event['title'] ?? '',
                style: TextStyle(
                  fontSize: 18,
                  color: ParishColors.textBlue900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event['time'] != null && event['time'].toString().isNotEmpty)
              _buildDetailRow(
                isOfficeHours ? Icons.access_time : Icons.access_time,
                t('Oras', 'Time'),
                event['time'],
              ),
            if (event['description'] != null &&
                event['description'].toString().isNotEmpty)
              _buildDetailRow(
                isOfficeHours ? Icons.work : Icons.description,
                isOfficeHours
                    ? t('Opisina', 'Office')
                    : t('Deskripsyon', 'Description'),
                event['description'],
              ),
            if (isBooking)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status == 'approved'
                      ? Colors.green.withValues(alpha: 0.1)
                      : status == 'pending'
                      ? ParishColors.primaryGold.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: status == 'approved'
                        ? Colors.green
                        : status == 'pending'
                        ? ParishColors.primaryGold
                        : Colors.red,
                  ),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: status == 'approved'
                        ? Colors.green
                        : status == 'pending'
                        ? ParishColors.primaryGold
                        : Colors.red,
                  ),
                ),
              ),
            if (event['type'] == 'office_closed')
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  event['description'] ?? '',
                  style: TextStyle(
                    color: ParishColors.textGray600,
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              t('Isara', 'Close'),
              style: TextStyle(color: ParishColors.primaryBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: ParishColors.textGray600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ParishColors.textGray600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ParishColors.textBlue900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: ParishColors.textGray700),
        ),
      ],
    );
  }

  List<Widget> _buildEventList(List<dynamic> events, bool isMobile) {
    if (events.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              t('Walang booking', 'No bookings'),
              style: TextStyle(
                color: ParishColors.textGray600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ];
    }

    return events.map((event) {
      final isBooking = event['type'] == 'booking';
      final isOfficeClosed = event['type'] == 'office_closed';
      final isOfficeHours = event['type'] == 'office_hours';
      final cardColor = isOfficeClosed
          ? Colors.black.withOpacity(0.05)
          : isBooking
          ? ParishColors.primaryGold.withValues(alpha: 0.1)
          : isOfficeHours
          ? ParishColors.grayDark.withValues(alpha: 0.1)
          : ParishColors.primaryBlue.withValues(alpha: 0.1);
      final borderColor = isOfficeClosed
          ? Colors.black26
          : isBooking
          ? ParishColors.primaryGold.withValues(alpha: 0.3)
          : isOfficeHours
          ? ParishColors.grayDark.withValues(alpha: 0.3)
          : ParishColors.primaryBlue.withValues(alpha: 0.3);
      final iconData = isBooking
          ? Icons.bookmark
          : isOfficeClosed
          ? Icons.business
          : isOfficeHours
          ? Icons.work
          : Icons.church;
      final iconColor = isBooking
          ? ParishColors.primaryGold
          : isOfficeClosed
          ? Colors.black87
          : isOfficeHours
          ? ParishColors.grayDark
          : ParishColors.primaryBlue;

      return GestureDetector(
        onTap: () => _showEventDetails(event),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(iconData, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['title'] ?? '',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: ParishColors.textBlue900,
                      ),
                    ),
                    if (event['time'] != null &&
                        event['time'].toString().isNotEmpty)
                      Text(
                        event['time'],
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: ParishColors.textGray600,
                        ),
                      ),
                    if (isOfficeHours &&
                        event['description'] != null &&
                        event['description'].toString().isNotEmpty &&
                        event['description'] != event['time'])
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          event['description'],
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: ParishColors.textGray600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: ParishColors.textGray600,
                size: 20,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);
    final columns = ParishResponsive.gridColumns(
      context,
      mobile: 2,
      tablet: 2,
      desktop: 3,
    );

    Widget sectionContainer({
      required String title,
      required List<Widget> children,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ParishColors.blue200.withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                color: ParishColors.textBlue900,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      );
    }

    Widget cardsGrid(List<Widget> cards) {
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: isMobile ? 0.85 : 1.05,
        children: cards,
      );
    }

    return SingleChildScrollView(
      child: ParishResponsiveScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Banner
            WelcomeBanner(
              userName: widget.userName,
              isMobile: isMobile,
              isTagalog: widget.isTagalog,
            ),
            SizedBox(height: isMobile ? 24 : 32),

            if (!widget.isGuest) ...[
              // Calendar Section - Mass Schedules & Bookings
              sectionContainer(
                title: t('Kalendaryo', 'Calendar'),
                children: [
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Column(
                      children: [
                        // Calendar Widget
                        TableCalendar(
                          firstDay: DateTime.utc(2024, 1, 1),
                          lastDay: DateTime.utc(2026, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          eventLoader: _getEventsForDay,
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: _buildDayBuilder,
                            todayBuilder: _buildDayBuilder,
                            selectedBuilder: _buildDayBuilder,
                            markerBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                          calendarStyle: CalendarStyle(
                            markersMaxCount: 3,
                            markerSize: 6,
                            selectedDecoration: const BoxDecoration(),
                            todayDecoration: const BoxDecoration(),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: true,
                            titleCentered: true,
                            formatButtonDecoration: BoxDecoration(
                              color: ParishColors.primaryBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            formatButtonTextStyle: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Legend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem(
                              ParishColors.primaryGold,
                              t('Mga Booking', 'Bookings'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Events for selected day
                        if (_selectedDay != null) ...[
                          Text(
                            t('Mga Booking', 'Bookings'),
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.textBlue900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._buildEventList(
                            _getEventsForDay(_selectedDay!),
                            isMobile,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              SizedBox(height: isMobile ? 24 : 32),
            ],

            // Parish Services Section
            Text(
              t(
                'Mga Serbisyo at Sakramento ng Parokya',
                'Parish Services and Sacraments',
              ),
              style: TextStyle(
                fontSize: isMobile ? 18 : 24,
                color: ParishColors.textBlue900,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),

            // Show loading state while checking age
            if (!widget.isGuest && _userAge == null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: const CircularProgressIndicator(),
              ),

            // Show age restriction message if under 18
            if (!widget.isGuest && _userAge != null && _userAge! < 18)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.red, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t(
                    'Hindi ka kailanman makakarehistro para sa mga sakramento sa iyong kasalukuyang edad.',
                    'You are not eligible to book sacraments at your current age.',
                  ),
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            if (widget.isGuest || (_userAge != null && _userAge! >= 18))
              sectionContainer(
                title: t('Mga Sakramento', 'Sacraments'),
                children: [
                  cardsGrid([
                    SacramentCard(
                      title: t('Binyag', 'Baptism'),
                      description: t(
                        'Sakramento ng Kristiyanong Pagsisimula',
                        'Sacrament of Christian Initiation',
                      ),
                      assetPath: SacramentType.baptism.assetPath(),
                      gradient: ParishGradients.baptismGradient,
                      onTap: () => widget.onSacramentTap(SacramentType.baptism),
                      isMobile: isMobile,
                    ),
                    SacramentCard(
                      title: t('Kumpil', 'Confirmation'),
                      description: t(
                        'Palakasin ang Iyong Pananampalataya',
                        'Strengthen your Faith',
                      ),
                      assetPath: SacramentType.confirmation.assetPath(),
                      gradient: ParishGradients.confirmationGradient,
                      onTap: () =>
                          widget.onSacramentTap(SacramentType.confirmation),
                      isMobile: isMobile,
                    ),
                    if (_isSacramentAvailable(SacramentType.wedding))
                      SacramentCard(
                        title: t('Kasal', 'Wedding'),
                        description: t('Banal na Kasal', 'Holy Marriage'),
                        assetPath: SacramentType.wedding.assetPath(),
                        gradient: ParishGradients.weddingGradient,
                        onTap: () =>
                            widget.onSacramentTap(SacramentType.wedding),
                        isMobile: isMobile,
                      ),
                    SacramentCard(
                      title: t('Misa para sa Yumao', 'Funeral Mass'),
                      description: t(
                        'Panalangin para sa Namatay',
                        'Prayer for the Departed',
                      ),
                      assetPath: SacramentType.funeral.assetPath(),
                      gradient: ParishGradients.funeralGradient,
                      onTap: () => widget.onSacramentTap(SacramentType.funeral),
                      isMobile: isMobile,
                    ),
                    SacramentCard(
                      title: t('Unang Komunyon', 'First Communion'),
                      description: t(
                        'Unang Pagtanggap ng Eukaristiya',
                        'First Reception of the Eucharist',
                      ),
                      assetPath: SacramentType.firstCommunion.assetPath(),
                      gradient: ParishGradients.firstCommunionGradient,
                      onTap: () =>
                          widget.onSacramentTap(SacramentType.firstCommunion),
                      isMobile: isMobile,
                    ),
                  ]),
                ],
              ),

            if (widget.isGuest || (_userAge != null && _userAge! >= 18))
              SizedBox(height: isMobile ? 12 : 16),

            if (widget.isGuest || (_userAge != null && _userAge! >= 18))
              sectionContainer(
                title: t('Mga Serbisyo', 'Services'),
                children: [
                  cardsGrid([
                    SacramentCard(
                      title: t('Basbas ng Bahay', 'House Blessing'),
                      description: t(
                        'Pagbasbas ng Tahanan',
                        'Blessing of Home',
                      ),
                      assetPath: SacramentType.houseBlessing.assetPath(),
                      gradient: ParishGradients.houseBlessingGradient,
                      onTap: () =>
                          widget.onSacramentTap(SacramentType.houseBlessing),
                      isMobile: isMobile,
                    ),
                    SacramentCard(
                      title: t(
                        'Pagpapahid sa May Sakit',
                        'Anointing of the Sick',
                      ),
                      description: t(
                        'Sakramento ng Pagpapagaling',
                        'Sacrament of Healing',
                      ),
                      assetPath: SacramentType.anointing.assetPath(),
                      gradient: ParishGradients.anointingGradient,
                      onTap: () =>
                          widget.onSacramentTap(SacramentType.anointing),
                      isMobile: isMobile,
                    ),
                    SacramentCard(
                      title: t('Intensyon ng Misa', 'Mass Intention'),
                      description: t(
                        'Mag-alay ng Intensyon',
                        'Offer an Intention',
                      ),
                      assetPath: SacramentType.massIntention.assetPath(),
                      gradient: ParishGradients.massIntentionGradient,
                      onTap: () =>
                          widget.onSacramentTap(SacramentType.massIntention),
                      isMobile: isMobile,
                    ),
                  ]),
                ],
              ),
            if (widget.isGuest || (_userAge != null && _userAge! >= 18))
              SizedBox(height: isMobile ? 24 : 32),
          ],
        ),
      ),
    );
  }
}
