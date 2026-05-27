import 'package:flutter/material.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/gradients.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/models/parish_profile.dart';

class ChurchHistoryScreen extends StatefulWidget {
  final bool isTagalog;

  const ChurchHistoryScreen({super.key, this.isTagalog = true});

  @override
  State<ChurchHistoryScreen> createState() => _ChurchHistoryScreenState();
}

class _ChurchHistoryScreenState extends State<ChurchHistoryScreen> {
  ParishProfile? _parishProfile;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadParishProfile();
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

      final debugInfo = await FirebaseService.instance.getParishProfileDebugInfo();
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

  String t(String tagalog, String english) => widget.isTagalog ? tagalog : english;

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
                      Text('Error loading parish history: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadParishProfile,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _parishProfile == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Parish profile not found'),
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
                                  // Pop the history screen and return to dashboard
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
                                    child: ClipOval(
                                      child: Image.asset(
                                        'lib/imgs/logo.jpeg',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    t(
                                      'Ang Kasaysayan ni Apo Sayong',
                                      'The History of Apo Sayong',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isMobile ? 20 : 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _parishProfile!.parishName,
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
                                // Introduction
                                _buildIntroductionCard(isMobile),
                                const SizedBox(height: 24),

                                // Timeline events
                                ..._parishProfile!.history.timelineEvents.map(
                                  (event) => Column(
                                    children: [
                                      _buildTimelineEvent(
                                        year: event.year,
                                        title: widget.isTagalog
                                            ? event.titleTagalog
                                            : event.titleEnglish,
                                        descriptions: widget.isTagalog
                                            ? event.descriptionsTagalog
                                            : event.descriptionsEnglish,
                                        isMobile: isMobile,
                                        isFirst: _parishProfile!.history.timelineEvents.first == event,
                                        isLast: _parishProfile!.history.timelineEvents.last == event,
                                      ),
                                      if (event != _parishProfile!.history.timelineEvents.last)
                                        const SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),

                                // Heritage Card
                                _buildHeritageCard(isMobile),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildIntroductionCard(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: ParishColors.bgBlue50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderBlue100, width: 2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParishColors.primaryGold,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.church,
                  color: ParishColors.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  t(
                    'Ang Pinagmulan ng Ating Pananampalataya',
                    'The Origin of Our Faith',
                  ),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w600,
                    color: ParishColors.textBlue900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.isTagalog
                ? _parishProfile!.history.introductionTagalog
                : _parishProfile!.history.introductionEnglish,
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

  Widget _buildTimelineEvent({
    required String year,
    required String title,
    required List<String> descriptions,
    required bool isMobile,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline marker and year
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                // Circle marker
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ParishColors.primaryGold,
                    border: Border.all(color: ParishColors.darkGold, width: 2),
                  ),
                ),
                // Connector line
                if (!isLast)
                  Container(
                    width: 3,
                    height: 80,
                    color: ParishColors.primaryGold.withValues(alpha: 0.3),
                    margin: const EdgeInsets.only(top: 8),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ParishColors.borderBlue100,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Year badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ParishColors.primaryGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ParishColors.primaryGold,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.isTagalog ? 'Taong $year' : 'Year $year',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ParishColors.darkGold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: ParishColors.textBlue900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Descriptions
                    ...descriptions.map(
                      (description) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6, right: 12),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  color: ParishColors.primaryGold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                description,
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 15,
                                  height: 1.6,
                                  color: ParishColors.textGray700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeritageCard(bool isMobile) {
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
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  t('Ating Pamana at Misyon', 'Our Heritage and Mission'),
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
            widget.isTagalog
                ? _parishProfile!.history.heritageTagalog
                : _parishProfile!.history.heritageEnglish,
            style: TextStyle(
              fontSize: isMobile ? 14 : 15,
              height: 1.8,
              color: ParishColors.textGray700,
            ),
          ),
        ],
      ),
    );
  }
}