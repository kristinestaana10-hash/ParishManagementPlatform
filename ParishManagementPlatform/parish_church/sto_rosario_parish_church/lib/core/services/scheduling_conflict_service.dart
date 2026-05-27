import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/scheduling_conflict_model.dart';

/// Service for detecting and preventing scheduling conflicts in bookings
class SchedulingConflictService {
  SchedulingConflictService._();
  static final SchedulingConflictService instance =
      SchedulingConflictService._();

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  static const List<String> _activeBookingStatuses = [
    'confirmed',
    'paid',
    'approved',
    'accepted',
    'pending',
    'Confirmed',
    'Paid',
    'Approved',
    'Accepted',
    'Pending',
  ];

  /// Check for scheduling conflicts before allowing a new booking
  ///
  /// Parameters:
  /// - [sacramentType]: The type of sacrament being booked
  /// - [date]: The date in YYYY-MM-DD format
  /// - [time]: The time (optional) - HH:MM AM/PM or HH:MM format
  /// - [excludeBookingId]: Booking ID to exclude from conflict check (for updates)
  ///
  /// Returns: [SchedulingConflictResult] with conflict details if found
  Future<SchedulingConflictResult> checkSchedulingConflict({
    required String sacramentType,
    required String date,
    String? time,
    String? excludeBookingId,
  }) async {
    try {
      debugPrint(
        'SchedulingConflictService: Checking conflict for $sacramentType on $date at $time',
      );

      // Normalize the sacrament type key
      final normalizedKey = _normalizeSacramentType(sacramentType);

      // Mass Intention bookings allow multiple bookings at same time.
      // They are validated separately against the official Mass schedule.
      if (RestrictedServiceType.isMassIntention(normalizedKey)) {
        debugPrint(
          'SchedulingConflictService: Mass Intention allows multiple bookings',
        );
        return SchedulingConflictResult.noConflict();
      }

      // For restricted services, check against all approved bookings
      if (!RestrictedServiceType.isRestricted(normalizedKey)) {
        debugPrint(
          'SchedulingConflictService: $normalizedKey is not a restricted service',
        );
        return SchedulingConflictResult.noConflict();
      }

      // Get all approved bookings from the database
      final bookings = await _getAllApprovedBookings();
      final requestedMinutes = time == null ? null : _parseTimeToMinutes(time);
      final requestedPeriod = requestedMinutes == null
          ? null
          : _schedulePeriod(requestedMinutes);
      debugPrint(
        'SchedulingConflictService: Found ${bookings.length} approved bookings total',
      );

      // Check for conflicts with existing bookings
      for (final booking in bookings) {
        debugPrint(
          'SchedulingConflictService: Checking booking - ID: ${booking.id}, Type: ${booking.sacramentType}, Date: ${booking.date}, Time: ${booking.time}, Status: ${booking.status}',
        );

        // Skip the same booking if updating
        if (excludeBookingId != null && booking.id == excludeBookingId) {
          debugPrint(
            'SchedulingConflictService: Skipping excluded booking ${booking.id}',
          );
          continue;
        }

        final bookingTypeKey = booking.sacramentTypeKey.isNotEmpty
            ? booking.sacramentTypeKey
            : _normalizeSacramentType(booking.sacramentType);
        if (!RestrictedServiceType.isRestricted(bookingTypeKey)) {
          continue;
        }

        if (bookingTypeKey != normalizedKey) {
          continue;
        }

        // Check if dates match
        if (booking.date != date) {
          debugPrint(
            'SchedulingConflictService: Date mismatch - booking: ${booking.date}, checking: $date',
          );
          continue;
        }

        if (time == null || time.trim().isEmpty || booking.time.isEmpty) {
          return SchedulingConflictResult.conflict(
            bookingId: booking.id,
            sacramentType: booking.sacramentType,
            userName: booking.userName ?? 'Another Parishioner',
            date: date,
            time: time,
            message:
                'A valid date and time are required to verify schedule availability.',
          );
        }

        final bookingMinutes = _parseTimeToMinutes(booking.time);
        if (requestedMinutes == null || bookingMinutes == null) {
          continue;
        }

        final minuteDifference = (requestedMinutes - bookingMinutes).abs();
        if (minuteDifference < 60) {
          return SchedulingConflictResult.conflict(
            bookingId: booking.id,
            sacramentType: booking.sacramentType,
            userName: booking.userName ?? 'Another Parishioner',
            date: date,
            time: time,
            message:
                'The selected date and time overlaps with another approved booking. Please choose a time at least 1 hour apart.',
          );
        }

        final bookingPeriod = _schedulePeriod(bookingMinutes);
        if (requestedPeriod != null && requestedPeriod == bookingPeriod) {
          return SchedulingConflictResult.conflict(
            bookingId: booking.id,
            sacramentType: booking.sacramentType,
            userName: booking.userName ?? 'Another Parishioner',
            date: date,
            time: time,
            message:
                'Only 1 $sacramentType booking is allowed in the $requestedPeriod schedule for this date. Please choose another available schedule.',
          );
        }
      }

      debugPrint('SchedulingConflictService: No conflicts detected');
      return SchedulingConflictResult.noConflict();
    } catch (e) {
      debugPrint('SchedulingConflictService: Error checking conflicts: $e');
      return SchedulingConflictResult.conflict(
        bookingId: '',
        sacramentType: sacramentType,
        userName: 'System',
        date: date,
        time: time,
        message:
            'Unable to verify schedule availability. Please try again before submitting.',
      );
    }
  }

  /// Validate Mass Intention schedule against official Mass Schedule table
  ///
  /// Returns: true if the schedule exists in the Mass Schedule database
  Future<bool> validateMassIntentionSchedule({
    required String date,
    required String time,
  }) async {
    try {
      debugPrint(
        'SchedulingConflictService: Validating Mass Intention schedule - $date at $time',
      );

      Future<bool> canReadSource(
        String sourceName,
        Future<bool> Function() read,
      ) async {
        try {
          return await read();
        } catch (e) {
          if (!e.toString().contains('permission-denied')) {
            debugPrint(
              'SchedulingConflictService: Could not read $sourceName Mass schedule: $e',
            );
          }
          return false;
        }
      }

      final isValid =
          await canReadSource(
            'mass_schedules',
            () => _massScheduleExists(
              collectionName: 'mass_schedules',
              date: date,
              time: time,
            ),
          ) ||
          await canReadSource(
            'massSchedules',
            () => _massScheduleExists(
              collectionName: 'massSchedules',
              date: date,
              time: time,
            ),
          ) ||
          await canReadSource(
            'parish_profile',
            () => _profileMassScheduleExists(date: date, time: time),
          );

      if (!isValid) {
        debugPrint(
          'SchedulingConflictService: Mass schedule NOT FOUND for $date at $time',
        );
      } else {
        debugPrint(
          'SchedulingConflictService: Mass schedule VALID for $date at $time',
        );
      }

      return isValid;
    } catch (e) {
      debugPrint(
        'SchedulingConflictService: Error validating Mass schedule: $e',
      );
      return false;
    }
  }

  /// Returns true when the selected date and time matches an official Mass
  /// schedule stored in Firestore/parish profile.
  Future<bool> isMassScheduleTime({
    required String date,
    required String time,
  }) {
    return validateMassIntentionSchedule(date: date, time: time);
  }

  /// Get all approved and pending bookings from the database
  Future<List<BookingRecord>> _getAllApprovedBookings() async {
    try {
      // Query all approved and pending bookings (status = 'confirmed', 'paid', 'approved', 'accepted', 'pending')
      final snapshot = await firestore
          .collection('bookings')
          .where(
            'status',
            whereIn: _activeBookingStatuses,
          )
          .get();

      final bookings = <BookingRecord>[];

      for (final doc in snapshot.docs) {
        try {
          final booking = BookingRecord.fromFirestore(doc.id, doc.data());

          // Only include bookings with valid date and time
          if (booking.date.isNotEmpty) {
            bookings.add(booking);
          }
        } catch (e) {
          debugPrint('SchedulingConflictService: Error parsing booking: $e');
        }
      }

      debugPrint(
        'SchedulingConflictService: Found ${bookings.length} approved bookings',
      );

      return bookings;
    } catch (e) {
      debugPrint(
        'SchedulingConflictService: Error fetching approved bookings: $e',
      );
      rethrow;
    }
  }

  /// Normalize sacrament type to canonical key format
  String _normalizeSacramentType(String sacramentType) {
    final s = sacramentType.toLowerCase().trim();

    if (s.contains('bapt') || s.contains('binyag')) return 'baptism';
    if (s.contains('confirm') || s.contains('kumpil')) return 'confirmation';
    if (s.contains('wedding') ||
        s.contains('kasal') ||
        s.contains('matrimony')) {
      return 'wedding';
    }
    if (s.contains('funeral') || s.contains('yumao')) return 'funeral';
    if ((s.contains('house') && s.contains('bless')) ||
        (s.contains('basbas') && s.contains('bahay'))) {
      return 'house_blessing';
    }
    if (s.contains('anoint') || s.contains('pagpapahid')) return 'anointing';
    if ((s.contains('first') && s.contains('communion')) ||
        (s.contains('unang') && s.contains('komunyon'))) {
      return 'first_communion';
    }
    if ((s.contains('mass') && s.contains('intention')) ||
        (s.contains('intensyon') && s.contains('misa'))) {
      return 'mass_intention';
    }

    return s;
  }

  String _schedulePeriod(int minutes) {
    return minutes < 12 * 60 ? 'AM' : 'PM';
  }

  int? _parseTimeToMinutes(String time) {
    final normalizedTime = time
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .trim();
    final match = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?[\s\u00A0\u202F]*([AaPp][Mm])?\b',
    ).firstMatch(normalizedTime);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '00');
    if (hour == null || minute == null || minute < 0 || minute > 59) {
      return null;
    }

    final meridiem = (match.group(3) ?? '').toLowerCase();
    if (meridiem.isNotEmpty) {
      if (hour < 1 || hour > 12) return null;
      if (meridiem == 'am') {
        hour = hour == 12 ? 0 : hour;
      } else {
        hour = hour == 12 ? 12 : hour + 12;
      }
    } else if (hour > 23) {
      return null;
    } else if (hour >= 1 && hour <= 5) {
      hour += 12;
    }

    return hour * 60 + minute;
  }

  Future<bool> _massScheduleExists({
    required String collectionName,
    required String date,
    required String time,
  }) async {
    final requestedMinutes = _parseTimeToMinutes(time);
    if (requestedMinutes == null) return false;

    final dateQuery = await firestore
        .collection(collectionName)
        .where('date', isEqualTo: date)
        .get();

    for (final doc in dateQuery.docs) {
      final data = doc.data();
      if (data['active'] == false) continue;

      final scheduleTime =
          (data['time'] ?? data['timeString'] ?? data['startTime'] ?? '')
              .toString();
      if (_parseTimeToMinutes(scheduleTime) == requestedMinutes) {
        return true;
      }
    }

    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) return false;

    final dayQuery = await firestore
        .collection(collectionName)
        .where('dayOfWeek', isEqualTo: _dayName(parsedDate))
        .get();

    for (final doc in dayQuery.docs) {
      final data = doc.data();
      if (data['active'] == false) continue;

      final scheduleTime =
          (data['time'] ?? data['timeString'] ?? data['startTime'] ?? '')
              .toString();
      if (_parseTimeToMinutes(scheduleTime) == requestedMinutes) {
        return true;
      }
    }

    return false;
  }

  String _dayName(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[date.weekday - 1];
  }

  Future<bool> _profileMassScheduleExists({
    required String date,
    required String time,
  }) async {
    final requestedMinutes = _parseTimeToMinutes(time);
    final parsedDate = DateTime.tryParse(date);
    if (requestedMinutes == null || parsedDate == null) return false;

    final documents = await _loadScheduleDocuments();

    for (final doc in documents) {
      final data = doc.data();
      if (data == null) continue;

      for (final text in _profileScheduleTexts(data)) {
        if (!_scheduleTextAppliesToDate(text, parsedDate)) continue;

        final scheduleTimes = _parseAllTimesToMinutes(text);
        if (scheduleTimes.contains(requestedMinutes)) {
          return true;
        }
      }
    }

    return false;
  }

  Future<List<DocumentSnapshot<Map<String, dynamic>>>>
  _loadScheduleDocuments() async {
    final documents = <DocumentSnapshot<Map<String, dynamic>>>[];
    final seenPaths = <String>{};

    Future<void> addDoc(DocumentSnapshot<Map<String, dynamic>> doc) async {
      if (!doc.exists) return;
      final path = doc.reference.path;
      if (seenPaths.add(path)) {
        documents.add(doc);
      }
    }

    Future<void> addCollection(String collectionName) async {
      try {
        final snapshot = await firestore
            .collection(collectionName)
            .limit(20)
            .get();
        for (final doc in snapshot.docs) {
          await addDoc(doc);
        }
      } catch (e) {
        debugPrint(
          'SchedulingConflictService: Could not read $collectionName schedules: $e',
        );
      }
    }

    try {
      await addDoc(
        await firestore.collection('parish_profile').doc('main').get(),
      );
    } catch (e) {
      debugPrint(
        'SchedulingConflictService: Could not read parish_profile/main: $e',
      );
    }

    await addCollection('parish_profile');
    await addCollection('schedule');
    await addCollection('schedules');

    try {
      final groupSnapshot = await firestore
          .collectionGroup('parish_profile')
          .limit(20)
          .get();
      for (final doc in groupSnapshot.docs) {
        await addDoc(doc);
      }
    } catch (e) {
      debugPrint(
        'SchedulingConflictService: Could not read parish_profile collection group: $e',
      );
    }

    return documents;
  }

  List<String> _profileScheduleTexts(Map<String, dynamic> data) {
    final raw =
        data['massSchedule'] ??
        data['mass_schedule'] ??
        data['massSchedules'] ??
        data['schedule'];
    final texts = <String>[];

    void addFrom(dynamic value) {
      if (value == null) return;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) texts.add(trimmed);
        return;
      }
      if (value is List<dynamic>) {
        for (final item in value) {
          addFrom(item);
        }
        return;
      }
      if (value is Map<String, dynamic>) {
        var foundNestedSchedule = false;
        for (final key in [
          'massSchedule',
          'mass_schedule',
          'massSchedules',
          'schedule',
        ]) {
          if (value[key] != null) {
            addFrom(value[key]);
            foundNestedSchedule = true;
          }
        }
        if (foundNestedSchedule) return;

        final day =
            (value['day'] ??
                    value['englishDay'] ??
                    value['tagalogDay'] ??
                    value['label'] ??
                    '')
                .toString()
                .trim();
        final scheduleTime =
            (value['time'] ??
                    value['timeString'] ??
                    value['scheduleTime'] ??
                    value['startTime'] ??
                    '')
                .toString()
                .trim();
        final combined = [
          day,
          scheduleTime,
        ].where((part) => part.isNotEmpty).join(' at ').trim();
        if (combined.isNotEmpty) texts.add(combined);
      }
    }

    addFrom(raw);

    if (texts.isEmpty) {
      for (final value in data.values) {
        addFrom(value);
      }
    }

    return texts;
  }

  List<int> _parseAllTimesToMinutes(String value) {
    final normalizedValue = value
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ');
    final matches = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?[\s\u00A0\u202F]*([AaPp][Mm])?\b',
    ).allMatches(normalizedValue);
    final times = <int>[];

    for (final match in matches) {
      final meridiem = match.group(3) ?? '';
      final normalized =
          '${match.group(1)}:${match.group(2) ?? '00'} $meridiem';
      final minutes = _parseTimeToMinutes(normalized);
      if (minutes != null && !times.contains(minutes)) {
        times.add(minutes);
      }
    }

    return times;
  }

  bool _scheduleTextAppliesToDate(String value, DateTime date) {
    final text = value.toLowerCase();
    final weekday = date.weekday;

    if (text.contains('mon-sat') ||
        text.contains('monday-saturday') ||
        text.contains('monday to saturday')) {
      return weekday >= DateTime.monday && weekday <= DateTime.saturday;
    }
    if (text.contains('mon-fri') ||
        text.contains('monday-friday') ||
        text.contains('monday to friday')) {
      return weekday >= DateTime.monday && weekday <= DateTime.friday;
    }
    if (text.contains('weekdays')) {
      return weekday >= DateTime.monday && weekday <= DateTime.friday;
    }
    if (text.contains('daily') || text.contains('everyday')) return true;

    const dayNames = {
      DateTime.monday: ['monday', 'mon'],
      DateTime.tuesday: ['tuesday', 'tue'],
      DateTime.wednesday: ['wednesday', 'wed'],
      DateTime.thursday: ['thursday', 'thu'],
      DateTime.friday: ['friday', 'fri'],
      DateTime.saturday: ['saturday', 'sat'],
      DateTime.sunday: ['sunday', 'sun'],
    };

    final mentionedDays = dayNames.entries
        .where((entry) => entry.value.any(text.contains))
        .map((entry) => entry.key)
        .toSet();

    if (mentionedDays.isEmpty) return true;
    return mentionedDays.contains(weekday);
  }

  /// Check multiple bookings for conflicts in batch
  /// Useful for admin operations checking multiple bookings at once
  Future<List<SchedulingConflictResult>> checkBatchConflicts(
    List<Map<String, String>> bookingsToCheck,
  ) async {
    final results = <SchedulingConflictResult>[];

    for (final booking in bookingsToCheck) {
      final result = await checkSchedulingConflict(
        sacramentType: booking['sacramentType'] ?? '',
        date: booking['date'] ?? '',
        time: booking['time'],
        excludeBookingId: booking['bookingId'],
      );

      results.add(result);
    }

    return results;
  }

  /// Get all bookings (including pending) for a specific date
  /// Useful for displaying availability calendar
  Future<List<BookingRecord>> getBookingsForDate(String date) async {
    try {
      final snapshot = await firestore
          .collection('bookings')
          .where('status', whereIn: _activeBookingStatuses)
          .get();

      return snapshot.docs
          .map((doc) => BookingRecord.fromFirestore(doc.id, doc.data()))
          .where((booking) => booking.date == date)
          .toList();
    } catch (e) {
      debugPrint(
        'SchedulingConflictService: Error fetching bookings for date: $e',
      );
      return [];
    }
  }

  /// Count active (approved or pending) bookings for a specific date
  /// Returns count of bookings with status 'approved', 'pending', 'confirmed', 'paid', or 'accepted'
  Future<int> countActiveBookingsForDate(String date) async {
    try {
      final snapshot = await firestore
          .collection('bookings')
          .where('status', whereIn: _activeBookingStatuses)
          .get();

      return snapshot.docs
          .map((doc) => BookingRecord.fromFirestore(doc.id, doc.data()))
          .where((booking) => booking.date == date)
          .length;
    } catch (e) {
      debugPrint(
        'SchedulingConflictService: Error counting bookings for date: $e',
      );
      return 0;
    }
  }

  /// Get all bookings for a date range
  Future<List<BookingRecord>> getBookingsForDateRange(
    String startDate,
    String endDate,
  ) async {
    try {
      final snapshot = await firestore
          .collection('bookings')
          .where('status', whereIn: _activeBookingStatuses)
          .get();

      return snapshot.docs
          .map((doc) => BookingRecord.fromFirestore(doc.id, doc.data()))
          .where(
            (booking) =>
                booking.date.compareTo(startDate) >= 0 &&
                booking.date.compareTo(endDate) <= 0,
          )
          .toList();
    } catch (e) {
      debugPrint(
        'SchedulingConflictService: Error fetching bookings for date range: $e',
      );
      return [];
    }
  }

  /// Get available time slots for a given date
  /// Returns list of times that are NOT booked
  Future<List<String>> getAvailableTimeSlots(
    String date,
    List<String> allPossibleTimeSlots,
  ) async {
    try {
      final bookings = await getBookingsForDate(date);
      final bookedTimes = bookings
          .map((b) => b.time.toLowerCase().trim())
          .where((t) => t.isNotEmpty)
          .toSet();

      return allPossibleTimeSlots
          .where((slot) => !bookedTimes.contains(slot.toLowerCase().trim()))
          .toList();
    } catch (e) {
      debugPrint(
        'SchedulingConflictService: Error getting available slots: $e',
      );
      return allPossibleTimeSlots;
    }
  }
}
