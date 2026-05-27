import 'package:flutter/material.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/gradients.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/models/parish_profile.dart';

class MassScheduleScreen extends StatefulWidget {
  final bool isTagalog;
  final List<MassScheduleItem>? schedule;

  const MassScheduleScreen({super.key, this.isTagalog = true, this.schedule});

  @override
  State<MassScheduleScreen> createState() => _MassScheduleScreenState();
}

class _MassScheduleScreenState extends State<MassScheduleScreen> {
  ParishProfile? _parishProfile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.schedule == null) {
      _loadParishProfile();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _loadParishProfile() async {
    try {
      final profile = await FirebaseService.instance.getParishProfile();
      if (profile != null) {
        setState(() {
          _parishProfile = profile;
          _isLoading = false;
        });
        return;
      }

      final debugInfo = await FirebaseService.instance
          .getParishProfileDebugInfo();
      setState(() {
        _error = 'No parish_profile document found. Debug info:\n$debugInfo';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<MassScheduleItem> get _schedule {
    if (widget.schedule != null) return widget.schedule!;
    if (_parishProfile != null) return _parishProfile!.massSchedule;
    return []; // Return empty list as fallback
  }

  List<OfficeScheduleItem> get _officeSchedule {
    if (_parishProfile != null) return _parishProfile!.officeSchedule;
    return [];
  }

  String t(String tagalog, String english) =>
      widget.isTagalog ? tagalog : english;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading mass schedule: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadParishProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                // Header with gradient background
                SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: ParishGradients.blueHeroGradient,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                              border: Border.all(
                                color: ParishColors.primaryGold,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.schedule,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t('Iskedyul ng Parokya', 'Parish Schedule'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _parishProfile?.parishName ??
                                'Sto. Rosario Parish Church',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: ParishColors.blue200,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Schedule Title
                        Text(
                          t('ISKEDYUL NG PAROKYA', 'PARISH SCHEDULE'),
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: ParishColors.textBlue900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Dynamic schedule from list
                        Builder(
                          builder: (context) {
                            final dailyMasses = _schedule
                                .where(
                                  (item) => item.category == MassCategory.daily,
                                )
                                .toList();
                            final sundayMasses = _schedule
                                .where(
                                  (item) =>
                                      item.category == MassCategory.sunday,
                                )
                                .toList();

                            final officeSchedule = _officeSchedule;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dailyMasses.isNotEmpty) ...[
                                  for (
                                    var i = 0;
                                    i < dailyMasses.length;
                                    i++
                                  ) ...[
                                    _buildMassCard(
                                      day: dailyMasses[i].label(
                                        widget.isTagalog,
                                      ),
                                      time: dailyMasses[i].time,
                                      icon: dailyMasses[i].icon,
                                      color: dailyMasses[i].color,
                                      isMobile: isMobile,
                                    ),
                                    if (i < dailyMasses.length - 1)
                                      const SizedBox(height: 16),
                                  ],
                                  const SizedBox(height: 32),
                                ],

                                if (sundayMasses.isNotEmpty) ...[
                                  Text(
                                    t('LINGGO', 'SUNDAY'),
                                    style: TextStyle(
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                      color: ParishColors.primaryBlue,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  for (
                                    var i = 0;
                                    i < sundayMasses.length;
                                    i++
                                  ) ...[
                                    _buildMassCard(
                                      day: sundayMasses[i].label(
                                        widget.isTagalog,
                                      ),
                                      time: sundayMasses[i].time,
                                      icon: sundayMasses[i].icon,
                                      color: sundayMasses[i].color,
                                      isMobile: isMobile,
                                    ),
                                    if (i < sundayMasses.length - 1)
                                      const SizedBox(height: 12),
                                  ],
                                  const SizedBox(height: 40),
                                ],

                                if (officeSchedule.isNotEmpty) ...[
                                  Text(
                                    t('ORAS NG OPISINA', 'OFFICE SCHEDULE'),
                                    style: TextStyle(
                                      fontSize: isMobile ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                      color: ParishColors.primaryBlue,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  for (
                                    var i = 0;
                                    i < officeSchedule.length;
                                    i++
                                  ) ...[
                                    _buildOfficeCard(
                                      label: officeSchedule[i].label(
                                        widget.isTagalog,
                                      ),
                                      time: officeSchedule[i].time,
                                      location: officeSchedule[i].location,
                                      description:
                                          officeSchedule[i].description,
                                      isMobile: isMobile,
                                    ),
                                    if (i < officeSchedule.length - 1)
                                      const SizedBox(height: 12),
                                  ],
                                  const SizedBox(height: 40),
                                ],

                                if (dailyMasses.isEmpty &&
                                    sundayMasses.isEmpty &&
                                    officeSchedule.isEmpty) ...[
                                  Text(
                                    t(
                                      'Walang schedule ng misa',
                                      'No mass schedule',
                                    ),
                                    style: TextStyle(
                                      fontSize: isMobile ? 14 : 16,
                                      color: ParishColors.textGray700,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ],
                            );
                          },
                        ),

                        // Info Card
                        _buildInfoCard(isMobile),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMassCard({
    required String day,
    required String time,
    required IconData icon,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderBlue100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: ParishColors.textBlue900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // Ensure displayed time is normalized for consistency
                  normalizeSimpleTime(time),
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Text(
              t('MISA', 'MASS'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeCard({
    required String label,
    required String time,
    required String location,
    required String description,
    required bool isMobile,
  }) {
    final officeColor = ParishColors.primaryBlue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderBlue100, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: officeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: officeColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(Icons.apartment, color: officeColor, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: ParishColors.textBlue900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  normalizeSimpleTime(time),
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: officeColor,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: ParishColors.textGray700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            color: ParishColors.textGray700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      color: ParishColors.textGray700,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: officeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: officeColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              t('OPISINA', 'OFFICE'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: officeColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ParishColors.primaryBlue.withValues(alpha: 0.1),
            ParishColors.primaryBlue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ParishColors.primaryBlue.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParishColors.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.info, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  t('Mahalagang Paalala', 'Important Reminder'),
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textBlue900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t(
              'Ang mga oras ng misa ay maaaring magbago. Mangyaring tumawag sa parokya para sa pinakabagong impormasyon.',
              'Mass times may change. Please call the parish for the most current information.',
            ),
            style: TextStyle(
              fontSize: isMobile ? 14 : 15,
              height: 1.6,
              color: ParishColors.textGray700,
            ),
          ),
        ],
      ),
    );
  }
}
