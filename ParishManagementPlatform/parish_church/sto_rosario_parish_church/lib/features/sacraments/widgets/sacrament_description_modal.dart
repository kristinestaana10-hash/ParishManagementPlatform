import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/gradients.dart';
import '../../../core/design/responsive.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/responsive_modal.dart';
import '../screens/sacrament_form_screen.dart';

class SacramentDescriptionModal extends StatefulWidget {
  final SacramentType sacramentType;
  final bool isTagalog;
  final bool canBook;
  final VoidCallback onBook;

  const SacramentDescriptionModal({
    super.key,
    required this.sacramentType,
    required this.isTagalog,
    this.canBook = true,
    required this.onBook,
  });

  @override
  State<SacramentDescriptionModal> createState() => _SacramentDescriptionModalState();
}

class _SacramentDescriptionModalState extends State<SacramentDescriptionModal> {
  int? _userAge;
  bool _isLoading = true;
  String? _ageEligibilityError;
  String? _databaseDescriptionEnglish;
  String? _databaseDescriptionTagalog;
  List<String> _databaseReminderEnglish = const [];
  List<String> _databaseReminderTagalog = const [];

  @override
  void initState() {
    super.initState();
    _loadBookingFormDefinition();
    _loadUserAge();
  }

  Future<void> _loadBookingFormDefinition() async {
    final data = await FirebaseService.instance.getBookingFormDefinition(
      widget.sacramentType.bookingFormKey,
    );
    if (!mounted || data == null) return;

    final descriptions = data['descriptions'] is Map
        ? Map<String, dynamic>.from(data['descriptions'] as Map)
        : const <String, dynamic>{};
    final reminders = data['reminders'] is Map
        ? Map<String, dynamic>.from(data['reminders'] as Map)
        : const <String, dynamic>{};

    List<String> parseList(dynamic value) {
      if (value is! List) return const [];
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    setState(() {
      _databaseDescriptionEnglish =
          (descriptions['english'] ?? data['descriptionEnglish'])?.toString();
      _databaseDescriptionTagalog =
          (descriptions['tagalog'] ?? data['descriptionTagalog'])?.toString();
      _databaseReminderEnglish = parseList(reminders['english']);
      _databaseReminderTagalog = parseList(reminders['tagalog']);
    });
  }

  int _calculateAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  String? _checkSacramentEligibility(int age) {
    if (age <= 17) {
      return widget.isTagalog
          ? 'Hindi ka kailanman makakarehistro para sa mga sakramento sa iyong kasalukuyang edad.'
          : 'You are not eligible to book sacraments at your current age.';
    }
    if (age >= 18 && age <= 20 && widget.sacramentType == SacramentType.wedding) {
      return widget.isTagalog
          ? 'Hindi ka kailanman makakarehistro para sa Kasal hanggang sa edad na 21.'
          : 'You are not eligible to book Wedding sacrament until age 21.';
    }
    return null;
  }

  Future<void> _loadUserAge() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }
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
            setState(() => _isLoading = false);
            return;
          }
          final age = _calculateAge(birthday);
          final eligibilityError = _checkSacramentEligibility(age);
          setState(() {
            _userAge = age;
            _ageEligibilityError = eligibilityError;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user age: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);
    final headerHeight = isMobile ? 120.0 : 160.0;

    // Show loading while checking age
    if (_isLoading) {
      return ResponsiveModal(
        scrollable: true,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              child: Container(
                height: headerHeight,
                decoration: BoxDecoration(gradient: _getGradient(widget.sacramentType)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      widget.sacramentType.assetPath(),
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.3),
                      colorBlendMode: BlendMode.darken,
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          widget.sacramentType.label(widget.isTagalog),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 22 : 28,
                            fontWeight: FontWeight.bold,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 4,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isMobile ? 20 : 24),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      );
    }

    return ResponsiveModal(
      scrollable: true,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image/Header
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            child: Container(
              height: headerHeight,
              decoration: BoxDecoration(gradient: _getGradient(widget.sacramentType)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    widget.sacramentType.assetPath(),
                    fit: BoxFit.cover,
                    color: Colors.black.withValues(alpha: 0.3),
                    colorBlendMode: BlendMode.darken,
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        widget.sacramentType.label(widget.isTagalog),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 22 : 28,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Description Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show age eligibility error if applicable
                if (_ageEligibilityError != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.red, width: 1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _ageEligibilityError!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_userAge != null) ...[const SizedBox(height: 8),
                          Text(
                            'Your Age: $_userAge',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                Text(
                  widget.isTagalog ? 'Tungkol sa Sakramento' : 'About the Sacrament',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textBlue900,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                Text(
                  _descriptionText(),
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isMobile ? 20 : 24),

                // Reminders Section
                _buildRemindersSection(context),

                SizedBox(height: isMobile ? 24 : 32),

                // Action Buttons
                ResponsiveModalActions(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        widget.isTagalog ? 'Kanselahin' : 'Cancel',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 15 : 16,
                        ),
                      ),
                    ),
                    if (widget.canBook)
                      ElevatedButton(
                        onPressed: _ageEligibilityError != null
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                widget.onBook();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ageEligibilityError != null
                              ? Colors.grey
                              : ParishColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 20 : 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          widget.isTagalog ? 'Mag-book Ngayon' : 'Book Now',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 15 : 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _descriptionText() {
    final databaseText = widget.isTagalog
        ? _databaseDescriptionTagalog
        : _databaseDescriptionEnglish;
    if (databaseText != null && databaseText.trim().isNotEmpty) {
      return databaseText.trim();
    }
    return widget.sacramentType.fullDescription(widget.isTagalog);
  }

  LinearGradient _getGradient(SacramentType type) {
    switch (type) {
      case SacramentType.baptism:
        return ParishGradients.baptismGradient;
      case SacramentType.confirmation:
        return ParishGradients.confirmationGradient;
      case SacramentType.wedding:
        return ParishGradients.weddingGradient;
      case SacramentType.funeral:
        return ParishGradients.funeralGradient;
      case SacramentType.houseBlessing:
        return ParishGradients.houseBlessingGradient;
      case SacramentType.anointing:
        return ParishGradients.anointingGradient;
      case SacramentType.massIntention:
        return ParishGradients.massIntentionGradient;
      case SacramentType.firstCommunion:
        return ParishGradients.firstCommunionGradient;
    }
  }

  Widget _buildRemindersSection(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);

    // No reminders for house blessing, anointing, mass intention, and first communion
    if (widget.sacramentType == SacramentType.houseBlessing ||
        widget.sacramentType == SacramentType.anointing ||
        widget.sacramentType == SacramentType.massIntention ||
        widget.sacramentType == SacramentType.firstCommunion) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: ParishColors.primaryGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ParishColors.primaryGold.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: ParishColors.primaryGold,
                size: isMobile ? 18 : 20,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                widget.isTagalog ? 'Mga Paalala' : 'Reminders',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.bold,
                  color: ParishColors.textBlue900,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          _buildReminderItem(
            widget.isTagalog
                ? 'Mangyaring mag-upload ng lahat ng valid na dokumento.'
                : 'Please upload all valid documents.',
            context,
          ),
          _buildReminderItem(
            widget.isTagalog
                ? 'Ang mga larawan ay dapat malinaw, nababasa, at de-kalidad (hindi blurred o cropped).'
                : 'Uploaded images must be clear, readable, and in good quality (not blurred or cropped).',
            context,
          ),
          ..._getSpecificReminders(context),
        ],
      ),
    );
  }

  Widget _buildReminderItem(String text, BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: ParishColors.primaryGold,
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getSpecificReminders(BuildContext context) {
    final reminders = <Widget>[];
    final databaseReminders = widget.isTagalog
        ? _databaseReminderTagalog
        : _databaseReminderEnglish;

    if (databaseReminders.isNotEmpty) {
      return databaseReminders
          .map((reminder) => _buildReminderItem(reminder, context))
          .toList(growable: false);
    }

    switch (widget.sacramentType) {
      case SacramentType.baptism:
        reminders.add(
          _buildReminderItem(
            widget.isTagalog
                ? 'Bayad sa Binyag - Weekdays: ₱1,650 (kasama ang damit ng bata at kandila) | Sunday pagkatapos ng Misa: ₱300'
                : 'Baptism Fee - Weekdays: ₱1,650 (includes cloths for child and candle) | Sunday after Mass: ₱300',
            context,
          ),
        );
        reminders.add(
          _buildImportantReminder(
            widget.isTagalog
                ? 'Kung ang mga magulang ay wala pa sa 18 taong gulang, hindi makakapag-book online. Kailangan nilang makipag-ugnayan sa parish office.'
                : 'If parents are below 18 years old, booking cannot proceed online. They must personally coordinate with the parish office.',
            context,
          ),
        );
        break;

      case SacramentType.confirmation:
        reminders.add(
          _buildReminderItem(
            widget.isTagalog
                ? 'Mangyaring i-upload ang mga kinakailangang dokumento at iba pang valid files.'
                : 'Please upload required documents and other valid files.',
            context,
          ),
        );
        reminders.add(
          _buildReminderItem(
            widget.isTagalog
                ? 'Siguraduhing kumpleto at malinaw ang lahat ng submitted files.'
                : 'Ensure all submitted files are complete and clear.',
            context,
          ),
        );
        break;

      case SacramentType.wedding:
        reminders.add(
          _buildImportantReminder(
            widget.isTagalog
                ? 'Kung ang ikakasal (bride o groom) ay wala pa sa 18 taong gulang, hindi maaaring mag-book ng kasal.'
                : 'If either the bride or groom is below 18 years old, the wedding is not allowed.',
            context,
          ),
        );
        reminders.add(
          _buildImportantReminder(
            widget.isTagalog
                ? 'Kung ang ikakasal ay 18 hanggang 20 taong gulang, kinakailangan ng parental guidance/consent. Kailangan nilang makipag-ugnayan sa parish office bago mag-proceed.'
                : 'If the couple is 18 to 20 years old, they must have parental guidance/consent. They are required to coordinate directly with the parish office before proceeding.',
            context,
          ),
        );
        break;

      default:
        break;
    }

    return reminders;
  }

  Widget _buildImportantReminder(String text, BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);

    return Container(
      margin: EdgeInsets.only(top: 4, bottom: isMobile ? 6 : 8),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade700,
            size: isMobile ? 18 : 20,
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                height: 1.4,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
