import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/document_validation_service.dart';
import '../../../features/sacraments/widgets/document_validation_widget.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/responsive.dart';

void _showModalNotificationGlobal(
  BuildContext context,
  String message, {
  Color bgColor = Colors.blue,
}) {
  bool isDialogOpen = true;
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor.withValues(alpha: 0.2),
              ),
              child: Icon(
                bgColor == ParishColors.greenSuccess
                    ? Icons.check_circle
                    : bgColor == Colors.red
                    ? Icons.error
                    : Icons.info,
                color: bgColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: ParishColors.textBlue900,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ).then((_) => isDialogOpen = false);

  // Auto-dismiss after 2 seconds
  Future.delayed(const Duration(seconds: 2), () {
    if (isDialogOpen && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  });
}

enum SacramentType {
  baptism,
  confirmation,
  wedding,
  funeral,
  houseBlessing,
  anointing,
  massIntention,
  firstCommunion,
  renewalOfVows,
}

extension SacramentTypeExtension on SacramentType {
  String label(bool isTagalog) {
    switch (this) {
      case SacramentType.baptism:
        return isTagalog ? 'Binyag' : 'Baptism';
      case SacramentType.confirmation:
        return isTagalog ? 'Kumpil' : 'Confirmation';
      case SacramentType.wedding:
        return isTagalog ? 'Kasal' : 'Wedding';
      case SacramentType.funeral:
        return isTagalog ? 'Misa para sa Yumao' : 'Funeral Mass';
      case SacramentType.houseBlessing:
        return isTagalog ? 'Basbas ng Bahay' : 'House Blessing';
      case SacramentType.anointing:
        return isTagalog ? 'Pagpapahid sa May Sakit' : 'Anointing of the Sick';
      case SacramentType.massIntention:
        return isTagalog ? 'Intensyon ng Misa' : 'Mass Intention';
      case SacramentType.firstCommunion:
        return isTagalog ? 'Unang Komunyon' : 'First Communion';
      case SacramentType.renewalOfVows:
        return isTagalog ? 'Pagpapanibago ng Panata' : 'Renewal of Vows';
    }
  }

  String assetPath() {
    switch (this) {
      case SacramentType.baptism:
        return 'lib/imgs/binyag.png';
      case SacramentType.confirmation:
        return 'lib/imgs/kumpil.png';
      case SacramentType.wedding:
        return 'lib/imgs/kasal.png';
      case SacramentType.funeral:
        return 'lib/imgs/misasayumao.png';
      case SacramentType.houseBlessing:
        return 'lib/imgs/basbassabahay.png';
      case SacramentType.anointing:
        return 'lib/imgs/pagpapahatidsamaysakit.png';
      case SacramentType.massIntention:
        return 'lib/imgs/intensyonsamisa.png';
      case SacramentType.firstCommunion:
        return 'lib/imgs/firstcommunion.png';
      case SacramentType.renewalOfVows:
        return 'lib/imgs/kasal.png';
    }
  }

}

enum BaptismTypeChoice { private, public }

extension SacramentTypeBookingFormKey on SacramentType {
  String get bookingFormKey {
    switch (this) {
      case SacramentType.baptism:
        return 'baptism';
      case SacramentType.confirmation:
        return 'confirmation';
      case SacramentType.wedding:
        return 'wedding';
      case SacramentType.funeral:
        return 'funeral';
      case SacramentType.houseBlessing:
        return 'house_blessing';
      case SacramentType.anointing:
        return 'anointing';
      case SacramentType.massIntention:
        return 'mass_intention';
      case SacramentType.firstCommunion:
        return 'first_communion';
      case SacramentType.renewalOfVows:
        return 'renewal_of_vows';
    }
  }
}

class _BookingAssistantSlot {
  final DateTime date;
  final String dateValue;
  final String timeValue;
  final int bookingCount;
  final int periodBookingCount;
  final String period;
  final String recommendation;

  const _BookingAssistantSlot({
    required this.date,
    required this.dateValue,
    required this.timeValue,
    required this.bookingCount,
    required this.periodBookingCount,
    required this.period,
    required this.recommendation,
  });
}

class _BookingAssistantResult {
  final _BookingAssistantSlot? bestSlot;
  final List<_BookingAssistantSlot> alternatives;
  final List<String> warnings;

  const _BookingAssistantResult({
    required this.bestSlot,
    required this.alternatives,
    required this.warnings,
  });
}

class SacramentFormData {
  final String title;
  final List<String> fields;
  final Map<String, Map<String, dynamic>> fieldDefinitions;
  final List<String> requirements;
  final Map<String, dynamic> fees;
  final Map<String, dynamic> schedules;
  final String descriptionEnglish;
  final String descriptionTagalog;

  const SacramentFormData({
    required this.title,
    required this.fields,
    required this.requirements,
    this.fieldDefinitions = const {},
    this.fees = const {},
    this.schedules = const {},
    this.descriptionEnglish = '',
    this.descriptionTagalog = '',
  });

  factory SacramentFormData.fromDatabase(
    Map<String, dynamic> data,
    SacramentFormData fallback,
  ) {
    List<String> stringList(dynamic value, List<String> fallbackValue) {
      if (value is List) {
        final parsed = value
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
        if (parsed.isNotEmpty) return parsed;
      }
      return fallbackValue;
    }

    Map<String, dynamic> mapValue(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      return const <String, dynamic>{};
    }

    final descriptions = mapValue(data['descriptions']);

    return SacramentFormData(
      title: (data['formName'] ?? data['title'] ?? fallback.title).toString(),
      fields: stringList(data['fields'], fallback.fields),
      requirements: stringList(data['requirements'], fallback.requirements),
      fieldDefinitions: fallback.fieldDefinitions,
      fees: mapValue(data['fees']),
      schedules: mapValue(data['schedules']),
      descriptionEnglish:
          (descriptions['english'] ??
                  data['descriptionEnglish'] ??
                  fallback.descriptionEnglish)
              .toString(),
      descriptionTagalog:
          (descriptions['tagalog'] ??
                  data['descriptionTagalog'] ??
                  fallback.descriptionTagalog)
              .toString(),
    );
  }

  static SacramentFormData forType(SacramentType type) {
    switch (type) {
      case SacramentType.baptism:
        return const SacramentFormData(
          title: 'Binyag Form',
          fields: [
            // PERSON TO BE BAPTIZED
            'First Name (Pangalan)',
            'Middle Name (Gitnang Pangalan)',
            'Surname (Apelyido)',
            'Suffix (Jr., II, etc.)',
            'Date of Birth (Petsa ng Kapanganakan)',
            'Age (Edad)',
            'Gender (Kasarian)',
            'Place of Birth (Lugar ng Kapanganakan)',
            // PARENTS INFORMATION - FATHER
            'Father First Name (Pangalan ng Ama)',
            'Father Middle Name (Gitnang Pangalan)',
            'Father Surname (Apelyido)',
            'Father Suffix (Jr., II, etc.)',
            'Father Place of Birth (Lugar ng Kapanganakan)',
            'Father Current Address (Bayan/Lungsod/Lalawigan)',
            // PARENTS INFORMATION - MOTHER
            'Mother First Name (Pangalan ng Ina)',
            'Mother Maiden Middle Name (Gitnang Pangalan sa Pagkadalaga)',
            'Mother Maiden Surname (Apelyido sa Pagkadalaga)',
            'Mother Place of Birth (Lugar ng Kapanganakan)',
            // MARRIAGE STATUS
            'Marriage Status',
            'Place of Marriage (Lugar ng Kasal)',
            'Date of Marriage (Petsa ng Kasal)',
            // OTHER INFORMATION
            'Minister of Baptism (Nagbinyag)',
            'Date of Baptism (Petsa ng Binyag)',
            'Time of Baptism (Oras ng Binyag)',
            // GODPARENTS - Primary
            'Primary Ninong Name',
            'Primary Ninong Age (18 pataas)',
            'Primary Ninong Address (Bayan/Lungsod/Lalawigan)',
            'Primary Ninang Name',
            'Primary Ninang Age (18 pataas)',
            'Primary Ninang Address (Bayan/Lungsod/Lalawigan)',
            // REGISTRATION DETAILS
            'Accomplished by (Nagrala)',
            'Relation to Baptized (Kaugnayan)',
            'Contact Number (Numero)',
            'Date Accomplished (Petsa ng Pagpapatala)',
            'Donation / AR Number',
            'Birth Certificate Registry No.',
            'Baptism Book No.',
            'Page',
            'Line',
            'Noted by (Tumanggap ng Pagpapatala)',
          ],
          requirements: ['Birth Certificate (PSA)'],
        );
      case SacramentType.confirmation:
        return const SacramentFormData(
          title: 'Kumpil Form',
          fields: [
            // CONFIRMATION DETAILS
            'Date of Confirmation (Petsa ng Kumpil)',
            'Day (Araw)',
            'Time (Oras)',
            // PERSONAL INFORMATION
            'Full Name (Pangalan ng Kukumpilan)',
            'Age (Edad)',
            'Gender (Kasarian)',
            'Date of Birth (Petsa ng Kapanganakan)',
            'Place of Birth (Lugar ng Kapanganakan)',
            // BAPTISMAL INFORMATION
            'Place of Baptism (Saan Nabinyagan)',
            'Date of Baptism (Kailan Nabinyagan)',
            'Parish Affiliation (Parokyang Kinabibilangan)',
            // PARENTS INFORMATION
            'Father\'s Name (Ama)',
            'Mother\'s Name (Ina - Apelyido noong dalaga pa)',
            // CONTACT INFORMATION
            'Current Address (Kasalukuyang Tirahan)',
            'Contact Number',
            // SPONSORS
            'Ninong Name (Pangalan)',
            'Ninong Age (Edad)',
            'Ninang Name (Pangalan)',
            'Ninang Age (Edad)',
          ],
          requirements: [
            'Birth Certificate (Sertipiko ng Kapanganakan)',
            'Baptismal Certificate (Sertipiko ng Binyag)',
          ],
        );
      case SacramentType.wedding:
        return const SacramentFormData(
          title: 'Kasal Form',
          fields: [
            // WEDDING DETAILS
            'Date of Wedding',
            'Day',
            'Time',
            // GROOM INFORMATION
            'Groom First Name',
            'Groom Middle Name',
            'Groom Surname',
            'Groom Age',
            'Groom Address',
            'Groom Place of Birth',
            'Groom Date of Birth',
            'Groom Religion',
            'Groom Status',
            'Groom Father Name',
            'Groom Mother Name',
            // BRIDE INFORMATION
            'Bride First Name',
            'Bride Middle Name',
            'Bride Surname',
            'Bride Age',
            'Bride Address',
            'Bride Place of Birth',
            'Bride Date of Birth',
            'Bride Religion',
            'Bride Status',
            'Bride Father Name',
            'Bride Mother Name',
            // CONTACT INFORMATION
            'Contact Number',
            // SPONSORS
            'Ninong Name',
            'Ninong Address',
            'Ninang Name',
            'Ninang Address',
          ],
          requirements: [
            'Groom Requirements:',
            '1. Birth Certificate (PSA)',
            '2. Marriage License/ Marriage Contract',
            '3. Baptismal Certificate (Marriage Purpose)',
            '4. Confirmation Certificate (Marriage Purpose)',
            '5. CENOMAR (PSA)',
            '6. Marriage Banns',
            '7. 2pcs. 2x2 pictures',
            '8. Wedding Invitation',
            'Bride Requirements:',
            '1. Birth Certificate (PSA)',
            '2. Marriage License/ Marriage Contract',
            '3. Baptismal Certificate (Marriage Purpose)',
            '4. Confirmation Certificate (Marriage Purpose)',
            '5. CENOMAR (PSA)',
            '6. Marriage Banns',
            '7. 2pcs. 2x2 pictures',
            '8. Wedding Invitation',
          ],
        );
      case SacramentType.funeral:
        return const SacramentFormData(
          title: 'Misa para sa Kapayapaan ng Kaluluwa',
          fields: [
            // PERSONAL INFORMATION
            'Full Name (Buong Pangalan ng Namatay)',
            'Nickname',
            'Age (Edad)',
            'Civil Status (Estado)',
            'Baptized (Binyagan)',
            'Spouse Name (Pangalan ng Asawa/Maybahay)',
            'Number of Children (Bilang ng Anak)',
            'Children Status',
            'Father\'s Name (Pangalan ng Tatay)',
            'Mother\'s Name (Pangalan ng Nanay)',
            'Date of Birth (Petsa ng Kapanganakan)',
            'Address (Tirahan)',
            'Parish Affiliation (Parokyang Kinabibilangan)',
            // SACRAMENTS RECEIVED
            'Confession (Kumpisal)',
            'Anointing of the Sick (Pagpapahid ng Langis)',
            'Viatico',
            'Church Service (Naging Lingkod ng Simbahan)',
            // DEATH AND BURIAL INFORMATION
            'Cause of Death (Sanhi ng Kamatayan)',
            'Date of Death (Petsa ng Kamatayan)',
            'Place of Death (Lugar ng Kamatayan)',
            'Burial Date (Petsa ng Libing)',
            'Burial Day (Araw ng Libing)',
            'Burial Time (Oras ng Libing)',
            'Burial Place (Lugar ng Libing)',
            'Burial Permit (Meron/Wala)',
            'Death Certificate (Meron/Wala)',
            // REGISTRATION DETAILS
            'Registered by (Pangalan ng Nagpalista)',
            'Relation to Deceased (Kaugnayan)',
            'Contact Number',
            'Date Registered (Petsa ng Pagpapatala)',
            'Donation / A.R. Number',
            'Death Certificate Registry No.',
            'Death Book No.',
            'Page',
            'Line',
            'Presiding Minister (Tagapagdiwang)',
            'Received by (Tumanggap ng Pagpapatala)',
          ],
          requirements: [
            'Burial Permit (Pahintulot sa Libing)',
            'Death Certificate (Sertipiko ng Kamatayan)',
          ],
        );
      case SacramentType.houseBlessing:
        return const SacramentFormData(
          title: 'Palista sa House Blessing',
          fields: [
            // REQUESTOR INFORMATION
            'Full Name (Pangalan)',
            'Address (Tirahan)',
            // BLESSING SCHEDULE
            'Date and Time of Blessing (Petsa at Oras ng Blessing)',
            'Phone Number (Cell/Tel. No.)',
            // PRIEST ARRIVAL
            'Time Priest Arrival (Oras ng Pagdating ng Pari)',
          ],
          requirements: [
            '1. Candles with wick base (Kandila - mas mainam na may sapo)',
            '2. Alms/Donation in bowl (Barya sa mangkok - kung gusto)',
            '3. Pick up priest at designated time (Sunduin ang pari sa oras na)',
          ],
        );
      case SacramentType.anointing:
        return const SacramentFormData(
          title: 'Palista sa Pagpapahid ng Langis sa May Sakit',
          fields: [
            // PATIENT INFORMATION
            'Full Name (Pangalan)',
            'Age (Edad)',
            'Illness/Condition (Sakit)',
            'Address (Tirahan)',
            'Phone Number (Cell/Tel. No.)',
            // APPOINTMENT
            'Date and Time (Petsa at Oras)',
          ],
          requirements: [
            '1. Ayusin at linisin ang maysakit (Ensure patient is cleaned and prepared)',
            '2. Krusipiho at 2 kandila sa basito (Crucifix and 2 candles in container)',
            '3. Sunduin ang pari sa oras na (Pick up priest at designated time)',
          ],
        );
      case SacramentType.massIntention:
        return const SacramentFormData(
          title: 'Intensyon ng Misa',
          fields: [
            // REQUESTOR INFORMATION
            'Full Name of Requestor (Buong Pangalan ng Nag-aalok)',
            'Contact Number (Numero ng Telepono)',
            // MASS INTENTION DETAILS
            'Feast or Name of Intended Person (Kapistahan o Pangalan ng Taong Iaalay)',
            // MASS SCHEDULE
            'Date of Mass (Petsa ng Misa)',
            'Time of Mass (Oras ng Misa)',
          ],
          requirements: [
            'Form must be filled out clearly (Puno ang form ng malinaw)',
            'Donation to be given before mass date (Paghahatid ng donasyon bago ang petsa ng misa)',
          ],
        );
      case SacramentType.firstCommunion:
        return const SacramentFormData(
          title: 'First Communion Request',
          fields: [
            // --- SCHOOL INFORMATION ---
            '[SECTION] SCHOOL INFORMATION (Impormasyon ng Paaralan)',
            'School Name (Pangalan ng Paaralan) *',
            'School Address (Tirahan ng Paaralan) *',
            'School Contact Number (Numero ng Telepono) *',
            'School Email Address (Email) *',
            'Principal Name (Pangalan ng Principal) *',
            // --- REQUEST DETAILS ---
            '[SECTION] REQUEST DETAILS (Detalye ng Kahilingan)',
            'Number of Students (Bilang ng Mag-aaral) *',
            'Grade Level (Baitang) *',
            'Preferred Date (Petsa na Nais) *',
            'Preferred Time (Oras na Nais) *',
            'Alternative Date (Alternatibong Petsa)',
            // --- CONTACT PERSON ---
            '[SECTION] CONTACT PERSON (Contact Person)',
            'Contact Person Name (Pangalan ng Kontak) *',
            'Contact Person Number (Numero ng Kontak) *',
            'Contact Person Email (Email ng Kontak) *',
            // --- ADDITIONAL INFORMATION ---
            '[SECTION] ADDITIONAL INFORMATION (Karagdagang Impormasyon)',
            'Special Requests (Espesyal na Kahilingan)',
            'Additional Notes (Karagdagang Paalala)',
          ],
          requirements: [],
        );
      case SacramentType.renewalOfVows:
        return const SacramentFormData(
          title: 'Renewal of Vows',
          fields: [],
          requirements: [],
        );
    }
  }
}

class SacramentFormScreen extends StatefulWidget {
  final SacramentType sacramentType;
  final bool isTagalog;
  final BaptismTypeChoice? initialBaptismType;

  const SacramentFormScreen({
    super.key,
    required this.sacramentType,
    this.isTagalog = true,
    this.initialBaptismType,
  });

  @override
  State<SacramentFormScreen> createState() => _SacramentFormScreenState();
}

class _ServicePaymentOption {
  final String id;
  final String label;
  final double amount;
  final String description;
  final bool isAddon;

  const _ServicePaymentOption({
    required this.id,
    required this.label,
    required this.amount,
    this.description = '',
    this.isAddon = false,
  });
}

class _SacramentFormScreenState extends State<SacramentFormScreen> {
  _SacramentFormScreenState(); // Add explicit constructor

  final _formKey = GlobalKey<FormState>();
  late SacramentFormData _data;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _dropdownValues;
  final Map<String, bool> _slotTakenCache = {};
  final Map<String, List<String>> _availableStandardSlotsByDate = {};
  final Set<String> _standardSlotAvailabilityLoadingDates = {};
  final Map<String, int> _bookingCountCache =
      {}; // Cache booking counts by date
  Future<void>? _bookingCountsLoadFuture;
  bool _bookingCountsLoaded = false;
  bool _isSubmitting = false;
  bool _paymentOptionsLoading = false;
  String? _paymentOptionsError;
  List<_ServicePaymentOption> _paymentOptions = const [];
  _ServicePaymentOption? _selectedPaymentOption;
  final Set<String> _selectedFeeAddonIds = {};
  bool _paymentOptionChosen = false;
  bool _formDefinitionLoading = true;
  String? _formDefinitionError;
  bool _isSundayBaptismDate = false;
  String? _sundayBaptismTime;
  bool _massScheduleLoading = false;
  bool _hasShownBookingAssistant = false;
  bool _isBookingAssistantOpen = false;
  List<String> _massScheduleTexts = [];
  StreamSubscription? _massScheduleSubscription;
  final List<Map<String, TextEditingController>> _additionalGodparents = [];
  final Map<int, PlatformFile?> _uploadedRequirementImages =
      {}; // Track uploaded images per requirement
  final Set<int> _requirementsToFollow = {};
  final Map<int, DocumentValidationResult> _validationResults = {};
  final Map<int, bool> _isValidatingDocuments = {};
  final Map<String, Map<String, String>> _existingCertificateCopies = {};
  bool _certificateCopiesLoading = true;

  // Age eligibility variables
  int? _userAge;
  bool _ageLoading = true;
  String? _ageEligibilityError;
  String _currentParishPriest = '';

  @override
  void initState() {
    super.initState();
    // Field definitions are intentionally loaded from booking_requirements.
    // Booking and validation rules remain in this screen; only the form
    // definition is data-driven.
    _data = const SacramentFormData(title: '', fields: [], requirements: []);
    _controllers = {};
    _dropdownValues = {};
    _loadBookingFormDefinition();
    if (_usesDatabasePaymentOptions) {
      _loadServicePaymentOptions();
    } else {
      _paymentOptionChosen = true;
    }
    if (widget.sacramentType != SacramentType.wedding) {
      _loadExistingCertificateCopies();
    }
    _loadUserAge();
    _loadCurrentParishPriest();
    // Pre-load booking counts for calendar (except Mass Intention)
    if (widget.sacramentType != SacramentType.massIntention) {
      _bookingCountsLoadFuture = _preloadBookingCounts();
    }
    // Regular booking-time dropdowns and Mass Intentions both depend on the
    // current parish Mass schedule.  Keep this live so an admin's schedule
    // change is reflected without returning to the form or using fixed slots.
    _loadMassIntentionSchedule();
    _listenForMassScheduleChanges();
  }

  Future<void> _loadExistingCertificateCopies() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _certificateCopiesLoading = false);
      return;
    }
    try {
      final requests = await FirebaseFirestore.instance
          .collection('certificate_requests')
          .where('userId', isEqualTo: uid)
          .get();
      final copies = <String, Map<String, String>>{};
      for (final request in requests.docs) {
        final data = request.data();
        final status = (data['status'] ?? '').toString().trim().toLowerCase();
        final isIssued = status == 'completed' ||
            status == 'ready to pick up' ||
            status == 'ready for pickup' ||
            status == 'ready to pickup';
        final urlValue = data['softCopyUrl'];
        if (!isIssued || urlValue is! String) continue;
        final url = urlValue.trim();
        final uri = Uri.tryParse(url);
        if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
        final type = _certificateRequestType(
          data['certificateType'] ?? data['certificateName'],
        );
        if (type == null) continue;
        final previous = copies[type];
        final date = data['requestDate'];
        final timestamp = date is Timestamp
            ? date.millisecondsSinceEpoch
            : date is DateTime
                ? date.millisecondsSinceEpoch
                : 0;
        final previousDate = int.tryParse(previous?['timestamp'] ?? '') ?? -1;
        if (previous == null || timestamp >= previousDate) {
          copies[type] = {
            'requestId': request.id,
            'url': url,
            'timestamp': timestamp.toString(),
            'certificateName': (data['certificateName'] ??
                    data['certificateType'] ??
                    'Church Certificate')
                .toString(),
          };
        }
      }
      if (mounted) {
        setState(() {
          _existingCertificateCopies
            ..clear()
            ..addAll(copies);
          _certificateCopiesLoading = false;
        });
      }
    } catch (error) {
      debugPrint('Could not load existing parish certificates: $error');
      if (mounted) setState(() => _certificateCopiesLoading = false);
    }
  }

  String? _certificateRequestType(Object? value) {
    final type = value?.toString().trim().toLowerCase() ?? '';
    if (type == 'baptism' || type.contains('baptis') || type.contains('binyag')) {
      return 'baptism';
    }
    if (type == 'confirmation' ||
        type.contains('confirm') ||
        type.contains('kumpil')) {
      return 'confirmation';
    }
    if (type == 'marriage' ||
        type.contains('wedding') ||
        type.contains('kasal') ||
        type.contains('marriage certificate') ||
        type.contains('certificate of marriage')) {
      return 'marriage';
    }
    return null;
  }

  String? _certificateTypeForRequirement(String requirement) {
    final text = requirement.toLowerCase();
    if (text.contains('baptism') || text.contains('binyag')) return 'baptism';
    if (text.contains('confirmation') || text.contains('kumpil')) {
      return 'confirmation';
    }
    if (text.contains('marriage certificate') ||
        text.contains('certificate of marriage') ||
        text.contains('wedding certificate') ||
        text.contains('sertipiko ng kasal')) {
      return 'marriage';
    }
    return null;
  }

  List<String> _massScheduleTextsFromProfile(dynamic profile) {
    if (profile == null) return const [];
    return profile.massSchedule
        .map((item) {
          final label = item.label(widget.isTagalog).trim();
          final time = item.time.trim();
          if (label.isEmpty) return time;
          if (time.isEmpty || label == time) return label;
          return '$label at $time';
        })
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  /// Reads the source field used by the parish profile editor. Keeping this
  /// separate from the display model also supports the existing `schedule`
  /// map/list formats stored in Firestore.
  List<String> _massScheduleTextsFromProfileData(Map<String, dynamic> data) {
    final texts = <String>[];

    void addFrom(dynamic value, {String day = ''}) {
      if (value == null) return;
      if (value is String) {
        final text = [day, value.trim()]
            .where((part) => part.isNotEmpty)
            .join(' at ');
        if (text.isNotEmpty) texts.add(text);
        return;
      }
      if (value is List) {
        for (final item in value) {
          addFrom(item, day: day);
        }
        return;
      }
      if (value is! Map) return;

      final map = Map<String, dynamic>.from(value);
      for (final key in [
        'massSchedule',
        'mass_schedule',
        'massSchedules',
        'schedule',
      ]) {
        if (map.containsKey(key)) {
          addFrom(map[key], day: day);
          return;
        }
      }

      final itemDay = (map['day'] ??
              map['englishDay'] ??
              map['tagalogDay'] ??
              map['label'] ??
              day)
          .toString()
          .trim();
      final time = (map['time'] ??
              map['timeString'] ??
              map['scheduleTime'] ??
              map['startTime'])
          ?.toString()
          .trim();
      if (time != null && time.isNotEmpty) {
        addFrom(time, day: itemDay);
        return;
      }

      // Also support a schedule map such as {"Monday": "9:00 AM"}.
      for (final entry in map.entries) {
        final label = entry.key == 'daily' || entry.key == 'sunday'
            ? entry.key
            : itemDay.isEmpty
                ? entry.key
                : itemDay;
        addFrom(entry.value, day: label);
      }
    }

    addFrom(data['massSchedule'] ??
        data['mass_schedule'] ??
        data['massSchedules'] ??
        data['schedule']);
    return texts.toSet().toList();
  }

  void _listenForMassScheduleChanges() {
    _massScheduleSubscription = FirebaseFirestore.instance
        .collection('parish_profile')
        .doc('main')
        .snapshots()
        .listen((snapshot) {
      if (!mounted || !snapshot.exists) return;
      final updatedSchedule =
          _massScheduleTextsFromProfileData(snapshot.data() ?? const {});
      if (updatedSchedule.isEmpty) return;

      setState(() {
        _massScheduleTexts = updatedSchedule;
        // Previously calculated availability used the old Mass schedule.
        _availableStandardSlotsByDate.clear();
      });

      final selectedDate = _selectedScheduleDate();
      if (selectedDate.isNotEmpty) {
        _refreshStandardSlotAvailability(selectedDate);
      }
    }, onError: (Object error) {
      debugPrint('Error listening for Mass schedule changes: $error');
    });
  }

  /// Pre-load booking counts for the next 365 days to support date disabling
  Future<void> _preloadBookingCounts() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDate = today.add(const Duration(days: 2)); // Lead time: 2 days
      final endDate = today.add(const Duration(days: 365));
      final startDateStr =
          '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final endDateStr =
          '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';

      debugPrint(
        '[CALENDAR] Pre-loading booking counts from $startDate to $endDate',
      );

      final bookingCounts = <String, int>{};

      Future<void> countCollection(String collectionName) async {
        try {
          Query<Map<String, dynamic>> query = FirebaseFirestore.instance
              .collection(collectionName);
          if (collectionName == 'bookings') {
            query = query.where(
              'status',
              whereIn: [
                'pending',
                'approved',
                'accepted',
                'confirmed',
                'paid',
                'Pending',
                'Approved',
                'Accepted',
                'Confirmed',
                'Paid',
              ],
            );
          }

          final snapshot = await query.get();

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = (data['status'] ?? 'pending').toString();
            if (!_isActiveBookingStatus(status)) continue;

            for (final dateKey in _bookingDocumentDates(data)) {
              if (dateKey.compareTo(startDateStr) < 0 ||
                  dateKey.compareTo(endDateStr) > 0) {
                continue;
              }
              bookingCounts[dateKey] = (bookingCounts[dateKey] ?? 0) + 1;
            }
          }
        } catch (e) {
          debugPrint('[CALENDAR] Could not count $collectionName dates: $e');
        }
      }

      // Both collections are independent. Loading them concurrently shortens
      // the cold-start wait before the assistant can use this cache.
      await Future.wait([
        countCollection('bookings'),
        countCollection('sacrament_requests'),
      ]);

      _bookingCountCache.clear();
      for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        _bookingCountCache[dateStr] = bookingCounts[dateStr] ?? 0;

        debugPrint(
          '[CALENDAR] Date $dateStr has ${_bookingCountCache[dateStr]} bookings',
        );
      }

      if (mounted) {
        setState(() {
          _bookingCountsLoaded = true;
        });
      } else {
        _bookingCountsLoaded = true;
      }
    } catch (e) {
      debugPrint('[CALENDAR] Error pre-loading booking counts: $e');
      _bookingCountsLoaded = false;
    }
  }

  Future<void> _loadMassIntentionSchedule() async {
    setState(() => _massScheduleLoading = true);
    try {
      final profile = await FirebaseService.instance.getParishProfile();
      if (!mounted) return;

      final scheduleTexts = <String>[..._massScheduleTextsFromProfile(profile)];
      // `schedule` is the field maintained by the parish profile editor.
      // Read its raw value as well because older profiles use a map instead
      // of the newer `massSchedule` list.
      final profileSnapshot = await FirebaseFirestore.instance
          .collection('parish_profile')
          .doc('main')
          .get();
      if (profileSnapshot.exists) {
        scheduleTexts.addAll(
          _massScheduleTextsFromProfileData(profileSnapshot.data() ?? const {}),
        );
      }

      setState(() {
        _massScheduleTexts = scheduleTexts.toSet().toList();
        _massScheduleLoading = false;
      });
      final selectedDate = _selectedScheduleDate();
      if (selectedDate.isNotEmpty) {
        await _refreshStandardSlotAvailability(selectedDate);
      }
    } catch (e) {
      debugPrint('Error loading Mass Intention schedule: $e');
      if (mounted) {
        setState(() => _massScheduleLoading = false);
      }
    }
  }

  Future<void> _loadCurrentParishPriest() async {
    try {
      final profile = await FirebaseService.instance.getParishProfile();
      if (!mounted) return;

      final priest = profile?.currentPriest.trim().isNotEmpty == true
          ? profile!.currentPriest.trim()
          : profile?.priest.trim() ?? '';

      setState(() {
        _currentParishPriest = priest;
      });

      const priestFieldKey = 'Registration - Priest\'s Name';
      final controller = _controllers[priestFieldKey];
      if (controller != null && controller.text.trim().isEmpty && priest.isNotEmpty) {
        controller.text = priest;
      }
    } catch (e) {
      debugPrint('Error loading current parish priest: $e');
    }
  }

  Future<List<String>> _loadMassScheduleTextsFromFirestore() async {
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
        var foundSchedule = false;
        for (final key in [
          'massSchedule',
          'mass_schedule',
          'massSchedules',
          'schedule',
        ]) {
          if (value[key] != null) {
            addFrom(value[key]);
            foundSchedule = true;
          }
        }
        if (foundSchedule) return;

        final day =
            (value['day'] ??
                    value['englishDay'] ??
                    value['tagalogDay'] ??
                    value['label'] ??
                    '')
                .toString()
                .trim();
        final time =
            (value['time'] ??
                    value['timeString'] ??
                    value['scheduleTime'] ??
                    value['startTime'] ??
                    '')
                .toString()
                .trim();
        final combined = [
          day,
          time,
        ].where((part) => part.isNotEmpty).join(' at ').trim();
        if (combined.isNotEmpty) texts.add(combined);
      }
    }

    Future<void> readCollection(String collectionName) async {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(collectionName)
            .limit(20)
            .get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final before = texts.length;
          addFrom(data);
          if (texts.length == before) {
            for (final value in data.values) {
              addFrom(value);
            }
          }
        }
      } catch (e) {
        debugPrint('Could not load Mass schedule from $collectionName: $e');
      }
    }

    await readCollection('schedule');
    await readCollection('schedules');

    return texts;
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
    if (age >= 18 &&
        age <= 20 &&
        widget.sacramentType == SacramentType.wedding) {
      return widget.isTagalog
          ? 'Hindi ka kailanman makakarehistro para sa Kasal hanggang sa edad na 21.'
          : 'You are not eligible to book Wedding sacrament until age 21.';
    }
    return null;
  }

  bool _usesSameDayAmPmSlotRules() {
    return {
      SacramentType.baptism,
      SacramentType.confirmation,
      SacramentType.wedding,
      SacramentType.funeral,
      SacramentType.houseBlessing,
      SacramentType.anointing,
    }.contains(widget.sacramentType);
  }

  bool _supportsBookingAssistant() {
    return !{
      SacramentType.massIntention,
      SacramentType.anointing,
      SacramentType.funeral,
      SacramentType.confirmation,
      SacramentType.firstCommunion,
    }.contains(widget.sacramentType);
  }

  bool _isSelectableSameDayAmPmBookingDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minimumLeadDays =
        widget.sacramentType == SacramentType.wedding ? 21 : 2;
    final earliestAllowedDate = today.add(Duration(days: minimumLeadDays));
    final day = DateTime(d.year, d.month, d.day);

    // Check basic criteria
    if (day.isBefore(earliestAllowedDate) || day.weekday == DateTime.monday) {
      return false;
    }

    if (_isFullyBookedDate(day)) {
      return false;
    }

    return true;
  }

  /// Check if a date is selectable with extended range (365 days) - used for optional dates like House Blessing
  /// Still respects the 4-booking limit per day
  bool _isSelectableFlexibleRangeBookingDate(DateTime d, int maxDaysAhead) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final blockUntil = today.add(const Duration(days: 2));
    final maxDate = now.add(Duration(days: maxDaysAhead));
    final day = DateTime(d.year, d.month, d.day);

    // Check date range
    if (!day.isAfter(blockUntil) || !day.isBefore(maxDate)) {
      return false;
    }

    if (_isFullyBookedDate(day)) {
      return false;
    }

    return true;
  }

  bool _isSelectableMassIntentionDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final maxDate = today.add(const Duration(days: 90));
    // Mass intentions retain their existing exception to the regular
    // two-day/Monday restrictions; the selected time is still checked against
    // the parish Mass schedule by the booking flow.
    return (day.isAtSameMomentAs(today) || day.isAfter(today)) &&
        day.isBefore(maxDate);
  }

  String _bookingDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  bool _isFullyBookedDate(DateTime date) {
    if (widget.sacramentType == SacramentType.massIntention) {
      return false;
    }

    final dateKey = _bookingDateKey(date);
    final bookingCount = _bookingCountCache[dateKey] ?? 0;
    if (bookingCount < 4) {
      return false;
    }

    debugPrint(
      '[CALENDAR] Date $dateKey is disabled: $bookingCount active bookings (max 4)',
    );
    return true;
  }

  String? _bookingDateWarningMessage(
    String date, {
    bool enforceLeadTime = true,
  }) {
    final parsedDate = DateTime.tryParse(date);
    if (parsedDate == null) {
      return widget.isTagalog
          ? 'Hindi valid ang napiling petsa. Mangyaring pumili muli ng petsa.'
          : 'The selected date is invalid. Please choose a date again.';
    }

    final requestedDate = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minimumLeadDays =
        widget.sacramentType == SacramentType.wedding ? 21 : 2;
    final earliestAllowedDate = today.add(Duration(days: minimumLeadDays));

    if (requestedDate.isBefore(today)) {
      return widget.isTagalog
          ? 'Hindi available ang napiling petsa. Pumili ng petsa ngayon o sa susunod na araw.'
          : 'The selected date is not available. Please choose today or a future date.';
    }

    if (widget.sacramentType != SacramentType.massIntention &&
        requestedDate.weekday == DateTime.monday) {
      return widget.isTagalog
          ? 'Hindi available ang napiling petsa dahil sarado ang parokya tuwing Lunes.'
          : 'The selected date is not available because the parish is closed on Mondays.';
    }

    if (widget.sacramentType != SacramentType.massIntention &&
        enforceLeadTime &&
        requestedDate.isBefore(earliestAllowedDate)) {
      return widget.isTagalog
          ? widget.sacramentType == SacramentType.wedding
                ? 'Hindi available ang petsa. Ang kasal ay kailangang i-book nang hindi bababa sa 3 linggo mula ngayon.'
                : 'Hindi available ang napiling petsa. Kailangan ang booking ay hindi bababa sa 2 araw mula ngayon.'
          : widget.sacramentType == SacramentType.wedding
                ? 'Wedding dates must be booked at least 3 weeks from today.'
                : 'The selected date is not available. Bookings must be at least 2 days from today.';
    }

    if (_isFullyBookedDate(requestedDate)) {
      return widget.isTagalog
          ? 'Hindi na available ang napiling petsa dahil mayroon na itong 4 pending o approved bookings.'
          : 'The selected date is no longer available because it already has 4 pending or approved bookings.';
    }

    return null;
  }

  String _selectedScheduleDate() {
    final keys = _selectedScheduleDateKeys();

    for (final key in keys) {
      final value = _controllers[key]?.text.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  List<String> _selectedScheduleDateKeys() {
    final keys = switch (widget.sacramentType) {
      SacramentType.baptism => ['Registration - Date of Baptism'],
      SacramentType.confirmation => ['Date of Confirmation (Petsa ng Kumpil)'],
      SacramentType.wedding => ['Date of Wedding'],
      SacramentType.funeral => ['Burial Date'],
      SacramentType.houseBlessing => ['Date of Blessing'],
      SacramentType.anointing => ['Appointment Date'],
      SacramentType.massIntention => ['Date of Mass (Petsa ng Misa)'],
      SacramentType.firstCommunion => [
        'Preferred Date (Petsa na Nais)',
        'Date of First Communion',
        'First Communion Date',
      ],
      SacramentType.renewalOfVows => _data.fields
          .where((field) {
            final value = field.toLowerCase();
            return (value.contains('date') || value.contains('petsa')) &&
                !value.contains('birth') &&
                !value.contains('kapanganakan');
          })
          .toList(growable: false),
    };
    return {..._databaseFieldKeys('date'), ...keys}.toList(growable: false);
  }

  String _selectedScheduleTime() {
    final keys = switch (widget.sacramentType) {
      SacramentType.baptism => ['Registration - Time of Baptism'],
      SacramentType.confirmation => ['Time (Oras)'],
      SacramentType.wedding => ['Time'],
      SacramentType.funeral => ['Burial Time'],
      SacramentType.houseBlessing => ['Time of Blessing'],
      SacramentType.anointing => ['Appointment Time'],
      SacramentType.massIntention => ['Time of Mass (Oras ng Misa)'],
      SacramentType.firstCommunion => [
        'Preferred Time (Oras na Nais)',
        'Time of First Communion',
        'First Communion Time',
      ],
      SacramentType.renewalOfVows => _data.fields
          .where((field) {
            final value = field.toLowerCase();
            return value.contains('time') || value.contains('oras');
          })
          .toList(growable: false),
    };

    keys.insertAll(0, _databaseFieldKeys('time'));

    for (final key in keys) {
      final value = _controllers[key]?.text.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  List<String> _selectedScheduleTimeKeys() {
    final keys = switch (widget.sacramentType) {
      SacramentType.baptism => ['Registration - Time of Baptism'],
      SacramentType.confirmation => ['Time (Oras)'],
      SacramentType.wedding => ['Time'],
      SacramentType.funeral => ['Burial Time'],
      SacramentType.houseBlessing => ['Time of Blessing'],
      SacramentType.anointing => ['Appointment Time'],
      SacramentType.massIntention => ['Time of Mass (Oras ng Misa)'],
      SacramentType.firstCommunion => [
        'Preferred Time (Oras na Nais)',
        'Time of First Communion',
        'First Communion Time',
      ],
      SacramentType.renewalOfVows => _data.fields
          .where((field) {
            final value = field.toLowerCase();
            return value.contains('time') || value.contains('oras');
          })
          .toList(growable: false),
    };
    return {..._databaseFieldKeys('time'), ...keys}.toList(growable: false);
  }

  bool get _usesDatabasePaymentOptions =>
      widget.sacramentType == SacramentType.baptism ||
      widget.sacramentType == SacramentType.wedding ||
      widget.sacramentType == SacramentType.renewalOfVows;

  double get _selectedPaymentTotal {
    final base = _selectedPaymentOption?.amount ?? 0;
    return base + _paymentOptions
        .where((fee) => fee.isAddon && _selectedFeeAddonIds.contains(fee.id))
        .fold<double>(0, (total, fee) => total + fee.amount);
  }

  String get _selectedPaymentLabel {
    final labels = <String>[
      if (_selectedPaymentOption != null) _selectedPaymentOption!.label,
      ..._paymentOptions
          .where((fee) => fee.isAddon && _selectedFeeAddonIds.contains(fee.id))
          .map((fee) => fee.label),
    ];
    return labels.join(' + ');
  }

  Future<void> _loadServicePaymentOptions() async {
    if (mounted) {
      setState(() {
        _paymentOptionsLoading = true;
        _paymentOptionsError = null;
      });
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('service_fees')
          .get();
      final matchingDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        final requestedId = switch (widget.sacramentType) {
          SacramentType.baptism => 'baptism',
          SacramentType.wedding => 'wedding',
          SacramentType.renewalOfVows => 'renewalofvows',
          _ => '',
        };
        final documentId = (data['id'] ?? doc.id)
            .toString()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z]'), '');
        return documentId == requestedId ||
            (requestedId == 'renewalofvows' &&
                documentId.contains('renewal') &&
                documentId.contains('vow'));
      });

      final options = <_ServicePaymentOption>[];
      double? parseAmount(dynamic value) => value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');

      String includesText(dynamic value) => value is List
          ? value.map((item) => item.toString()).join(', ')
          : '';

      final selectedService = matchingDocs.isEmpty
          ? null
          : matchingDocs.first.data();
      if (selectedService != null &&
          widget.sacramentType == SacramentType.baptism) {
        final packages = selectedService['packages'];
        if (packages is Map) {
          for (final entry in packages.entries) {
            if (entry.value is! Map) continue;
            final package = Map<String, dynamic>.from(entry.value as Map);
            final amount = parseAmount(package['amount']);
            if (amount == null || amount <= 0) continue;
            options.add(_ServicePaymentOption(
              id: (package['id'] ?? entry.key).toString(),
              label: (package['label'] ?? entry.key).toString(),
              amount: amount,
              description: includesText(package['includes']),
            ));
          }
        }
      } else if (selectedService != null &&
          (widget.sacramentType == SacramentType.wedding ||
              widget.sacramentType == SacramentType.renewalOfVows)) {
        final baseAmount = parseAmount(selectedService['baseAmount']);
        if (baseAmount != null && baseAmount > 0) {
          options.add(_ServicePaymentOption(
            id: 'base',
            label: widget.sacramentType == SacramentType.renewalOfVows
                ? (widget.isTagalog
                    ? 'Pangunahing bayad sa Pagpapanibago ng Panata'
                    : 'Renewal of Vows base fee')
                : (widget.isTagalog
                    ? 'Pangunahing bayad sa Kasal'
                    : 'Wedding base fee'),
            amount: baseAmount,
          ));
        }
        final addons = selectedService['addons'];
        if (addons is Map) {
          for (final entry in addons.entries) {
            if (entry.value is! Map) continue;
            final addon = Map<String, dynamic>.from(entry.value as Map);
            final amount = parseAmount(addon['amount']);
            if (amount == null || amount <= 0) continue;
            options.add(_ServicePaymentOption(
              id: (addon['id'] ?? entry.key).toString(),
              label: (addon['label'] ?? entry.key).toString(),
              amount: amount,
              isAddon: true,
            ));
          }
        }
      }
      final uniqueOptions = <String, _ServicePaymentOption>{};
      for (final option in options) {
        uniqueOptions.putIfAbsent(option.id, () => option);
      }
      final loadedOptions = uniqueOptions.values.toList();
      _ServicePaymentOption? baseOption;
      if (widget.sacramentType == SacramentType.wedding ||
          widget.sacramentType == SacramentType.renewalOfVows) {
        for (final option in loadedOptions) {
          if (!option.isAddon) {
            baseOption = option;
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _paymentOptions = loadedOptions;
        _selectedPaymentOption =
            (widget.sacramentType == SacramentType.wedding ||
                widget.sacramentType == SacramentType.renewalOfVows)
            ? baseOption
            : null;
        _selectedFeeAddonIds.clear();
        _paymentOptionsError = _paymentOptions.isEmpty
            ? (widget.isTagalog
                ? 'Walang fees na naka-set sa database para sa serbisyong ito.'
                : 'No fees are configured in service_fees for this service.')
            : null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _paymentOptionsError =
            'Unable to load payment options: $error');
      }
    } finally {
      if (mounted) setState(() => _paymentOptionsLoading = false);
    }
  }

  List<String> _databaseFieldKeys(String fieldType) {
    final configuredFieldKeys = _data.schedules[
      fieldType == 'date' ? 'dateFieldKeys' : 'timeFieldKeys'
    ];
    final configuredNames = configuredFieldKeys is List
        ? configuredFieldKeys.map((value) => value.toString().trim()).toList()
        : const <String>[];

    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final configuredMatches = <String>[];
    for (final configuredName in configuredNames) {
      final normalizedName = normalize(configuredName);
      for (final field in _data.fields) {
        if (normalize(field) == normalizedName &&
            !configuredMatches.contains(field)) {
          configuredMatches.add(field);
        }
      }
    }

    final inferredFields = _data.fields.where((field) {
      final type = (_data.fieldDefinitions[field]?['type'] ?? '')
          .toString()
          .toLowerCase();
      final normalized =
          '$field ${_data.fieldDefinitions[field]?['label'] ?? ''}'
              .toLowerCase();
      if (fieldType == 'date' &&
          (normalized.contains('birth') || normalized.contains('kapanganakan'))) {
        return false;
      }
      if (fieldType == 'date' &&
          widget.sacramentType == SacramentType.confirmation &&
          (normalized.contains('baptiz') || normalized.contains('binyag'))) {
        return false;
      }
      if (widget.sacramentType == SacramentType.baptism) {
        final isBaptismScheduleField =
            normalized.contains('baptism') ||
            normalized.contains('binyag') ||
            normalized.contains('registration') ||
            (fieldType == 'time' && normalized.trim() == 'time');
        if (!isBaptismScheduleField) return false;
      }
      return type == fieldType ||
          normalized.contains(fieldType) ||
          (fieldType == 'date' && normalized.contains('petsa')) ||
          (fieldType == 'time' && normalized.contains('oras'));
    }).toList(growable: false);
    return [...configuredMatches, ...inferredFields]
        .toSet()
        .toList(growable: false);
  }

  void _clearSelectedScheduleTime() {
    for (final key in _selectedScheduleTimeKeys()) {
      _controllers[key]?.clear();
    }
  }

  Future<void> _loadBookingFormDefinition() async {
    try {
      final data = await FirebaseService.instance.getBookingFormDefinition(
        widget.sacramentType.bookingFormKey,
      );
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _formDefinitionLoading = false;
          _formDefinitionError = 'No booking form definition was found.';
        });
        return;
      }

      final rawFields = data['formFields'] ?? data['fields'];
      if (rawFields is! List) {
        setState(() {
          _formDefinitionLoading = false;
          _formDefinitionError = 'The booking form has no fields configured.';
        });
        return;
      }

      final configuredFields = List<dynamic>.from(rawFields);
      if (widget.sacramentType == SacramentType.confirmation) {
        final hasConfirmationDateField = configuredFields.any((rawField) {
          if (rawField is! Map) return false;
          final definition = Map<String, dynamic>.from(rawField);
          if (definition['visible'] == false) return false;
          final identity = '${definition['name'] ?? definition['key'] ?? ''} '
                  '${definition['label'] ?? ''}'
              .toLowerCase();
          return (identity.contains('date') || identity.contains('petsa')) &&
              (identity.contains('confirmation') ||
                  identity.contains('kumpil'));
        });
        if (!hasConfirmationDateField) {
          configuredFields.add({
            'name': 'Date of Confirmation (Petsa ng Kumpil)',
            'label': 'Date of Confirmation (Petsa ng Kumpil)',
            'type': 'date',
            'required': true,
            'visible': true,
            'section': 'Confirmation Schedule',
          });
        }

        final scheduledTime = data['scheduledTime']?.toString().trim() ?? '';
        if (scheduledTime.isNotEmpty) {
          final timeFieldIndex = configuredFields.indexWhere((rawField) {
            if (rawField is! Map) return false;
            final definition = Map<String, dynamic>.from(rawField);
            if (definition['visible'] == false) return false;
            final identity = '${definition['name'] ?? definition['key'] ?? ''} '
                    '${definition['label'] ?? ''}'
                .toLowerCase();
            final type = (definition['type'] ?? '').toString().toLowerCase();
            return type == 'time' ||
                identity.contains('time') ||
                identity.contains('oras');
          });

          if (timeFieldIndex == -1) {
            configuredFields.add({
              'name': 'Time (Oras)',
              'label': 'Time (Oras)',
              'type': 'time',
              'options': [scheduledTime],
              'required': true,
              'visible': true,
              'section': 'Confirmation Schedule',
            });
          } else {
            final definition = Map<String, dynamic>.from(
              configuredFields[timeFieldIndex] as Map,
            );
            final options = definition['options'] is List
                ? List<dynamic>.from(definition['options'] as List)
                : <dynamic>[];
            if (!options.any(
              (option) => option.toString().trim() == scheduledTime,
            )) {
              options.add(scheduledTime);
            }
            definition['options'] = options;
            configuredFields[timeFieldIndex] = definition;
          }
        }
      }

      final fields = <String>[];
      final fieldDefinitions = <String, Map<String, dynamic>>{};
      for (final rawField in configuredFields) {
        if (rawField is Map) {
          final definition = Map<String, dynamic>.from(rawField);
          if (definition['visible'] == false) continue;
          final name = (definition['name'] ??
                  definition['key'] ??
                  definition['label'] ??
                  '')
              .toString()
              .trim();
          if (name.isEmpty) continue;
          fields.add(name);
          fieldDefinitions[name] = definition;
        } else {
          final name = rawField?.toString().trim() ?? '';
          if (name.isNotEmpty) fields.add(name);
        }
      }

      var nextData = SacramentFormData.fromDatabase(data, _data);
      // Do not fall back to application-defined fields. An empty list is a
      // valid database-controlled form definition.
      nextData = SacramentFormData(
        title: nextData.title,
        fields: fields,
        fieldDefinitions: fieldDefinitions,
        requirements: (data['requirements'] ??
                    data['requiredDocuments'] ??
                    data['documents']) is List
            ? ((data['requirements'] ??
                        data['requiredDocuments'] ??
                        data['documents']) as List)
                  .map((item) => item?.toString().trim() ?? '')
                  .where((item) => item.isNotEmpty)
                  .toList(growable: false)
            : const [],
        fees: nextData.fees,
        schedules: nextData.schedules,
        descriptionEnglish: nextData.descriptionEnglish,
        descriptionTagalog: nextData.descriptionTagalog,
      );
    if (widget.sacramentType == SacramentType.massIntention) {
      nextData = SacramentFormData(
        title: nextData.title,
        fields: nextData.fields
            .where((field) => !_isDonationArNumberField(field))
            .toList(growable: false),
        fieldDefinitions: nextData.fieldDefinitions,
        requirements: nextData.requirements,
        fees: nextData.fees,
        schedules: nextData.schedules,
        descriptionEnglish: nextData.descriptionEnglish,
        descriptionTagalog: nextData.descriptionTagalog,
      );
    }

    setState(() {
      _data = nextData;
      _formDefinitionLoading = false;
      _formDefinitionError = null;
      final activeFields = _data.fields.toSet();
      final removedFields = _controllers.keys
          .where((field) => !activeFields.contains(field))
          .toList(growable: false);
      for (final field in removedFields) {
        _controllers.remove(field)?.dispose();
      }
      for (final field in _data.fields) {
        _controllers.putIfAbsent(field, TextEditingController.new);
      }
    });

    if (widget.sacramentType == SacramentType.confirmation) {
      final scheduledDate = data['scheduledDate']?.toString().trim() ?? '';
      final dateKey = _selectedScheduleDateKeys().firstWhere(
        _controllers.containsKey,
        orElse: () => 'Date of Confirmation (Petsa ng Kumpil)',
      );
      if (scheduledDate.isNotEmpty &&
          (_controllers[dateKey]?.text.trim().isEmpty ?? true)) {
        _controllers[dateKey]?.text = scheduledDate;
      }

      final scheduledTime = data['scheduledTime']?.toString().trim() ?? '';
      final parsedScheduledTime = _parseTimeOfDay(scheduledTime);
      final timeKey = _selectedScheduleTimeKeys().firstWhere(
        _controllers.containsKey,
        orElse: () => 'Time (Oras)',
      );
      if (parsedScheduledTime != null &&
          (_controllers[timeKey]?.text.trim().isEmpty ?? true)) {
        _controllers[timeKey]?.text = _formatTimeOfDay(parsedScheduledTime);
      }

    }
    } catch (error) {
      debugPrint('Failed to load booking form definition: $error');
      if (mounted) {
        setState(() {
          _formDefinitionLoading = false;
          _formDefinitionError = 'Unable to load the booking form.';
        });
      }
    }
  }

  Future<bool> _isBlockedByMassSchedule({
    required String date,
    required String time,
  }) async {
    if (widget.sacramentType == SacramentType.massIntention ||
        date.trim().isEmpty ||
        time.trim().isEmpty) {
      return false;
    }

    return FirebaseService.instance.isMassScheduleTime(
      date: date.trim(),
      time: time.trim(),
    );
  }

  bool _isDonationArNumberField(String field) {
    final normalized = field.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.contains('donation') && normalized.contains('arnumber');
  }

  void _showMassScheduleBlockedMessage() {
    _showModalNotificationGlobal(
      context,
      widget.isTagalog
          ? 'Hindi puwedeng mag-book sa oras ng Misa. Pumili ng ibang oras.'
          : 'You cannot book during Mass schedule. Please choose another time.',
      bgColor: Colors.red,
    );
  }

  Future<void> _loadUserAge() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _ageLoading = false);
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
            setState(() => _ageLoading = false);
            return;
          }
          final age = _calculateAge(birthday);
          final eligibilityError = _checkSacramentEligibility(age);
          setState(() {
            _userAge = age;
            _ageEligibilityError = eligibilityError;
            _ageLoading = false;
          });
        } else {
          setState(() => _ageLoading = false);
        }
      } else {
        setState(() => _ageLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user age: $e');
      setState(() => _ageLoading = false);
    }
  }

  @override
  void dispose() {
    _massScheduleSubscription?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final godparent in _additionalGodparents) {
      for (final controller in godparent.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _addGodparent() {
    setState(() {
      _additionalGodparents.add({
        'Name': TextEditingController(),
        'Age': TextEditingController(),
        'Religion': TextEditingController(),
        'Address': TextEditingController(),
      });
    });
  }

  Future<void> _uploadRequirementImage(int requirementIndex) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result != null) {
        final platformFile = result.files.single;

        // Show loading indicator
        setState(() {
          _isValidatingDocuments[requirementIndex] = true;
        });

        // Validate document before allowing upload
        final validationResult =
            await DocumentValidationService.validateDocument(
              documentFile: platformFile,
              sacramentType: widget.sacramentType.name,
              requirementType: _data.requirements[requirementIndex],
            );

        setState(() {
          _isValidatingDocuments[requirementIndex] = false;
        });

        // Debug: Print validation results
        print(
          'Validation Result - Valid: ${validationResult.isValid}, Confidence: ${validationResult.confidenceScore}%',
        );
        print('Missing Fields: ${validationResult.missingFields}');
        print('Invalid Fields: ${validationResult.invalidFields}');
        print(
          'Requirements: ${widget.sacramentType.name} - ${_data.requirements[requirementIndex]}',
        );

        // PROPER VALIDATION LOGIC - Now that OCR is fixed
        final confidenceScore = validationResult.confidenceScore;
        final hasCriticalErrors = validationResult.errorMessage != null;

        // Confidence Threshold: Must be >= 30%
        if (validationResult.isValid &&
            confidenceScore >= 30 &&
            !hasCriticalErrors) {
          // SUCCESS LOGIC: Only after validation passes, store file locally
          setState(() {
            _uploadedRequirementImages[requirementIndex] = platformFile;
            _validationResults[requirementIndex] = validationResult;
            _requirementsToFollow.remove(requirementIndex);
          });

          final didAutoFill = await _reviewAndAutoFillOcrData(
            validationResult,
            requirementIndex,
          );
          if (!didAutoFill && mounted) {
            _showModalNotificationGlobal(
              context,
              widget.isTagalog
                  ? 'Matagumpay na na-upload. Walang detalyeng awtomatikong idinagdag.'
                  : 'Successfully uploaded. No details were auto-filled.',
              bgColor: ParishColors.greenSuccess,
            );
          }
        } else {
          // BLOCKING: Score < 30% or critical errors - block upload completely
          _showValidationFailureDialog(validationResult, requirementIndex);
        }
      }
    } catch (e) {
      setState(() {
        _isValidatingDocuments[requirementIndex] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isTagalog
                ? 'May error sa pag-upload ng file: $e'
                : 'Error uploading file: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showValidationFailureDialog(
    DocumentValidationResult result,
    int requirementIndex,
  ) {
    final serviceUnavailable = result.missingFields.contains(
      'document_verification_service',
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                serviceUnavailable ? Icons.cloud_off : Icons.error,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                serviceUnavailable
                    ? (widget.isTagalog
                          ? 'Hindi Available ang Pag-verify'
                          : 'Document Verification Unavailable')
                    : (widget.isTagalog
                          ? 'Di Validong Dokumento'
                          : 'Invalid Document'),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    serviceUnavailable
                        ? (widget.isTagalog
                              ? 'Hindi napatunayan ang dokumento dahil hindi available ang verification service.'
                              : 'The document was not verified because the verification service is unavailable.')
                        : (widget.isTagalog
                              ? 'Hindi namin makilalang mabuti ang dokumentong ito.'
                              : 'We could not recognize this document.'),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                if (result.errorMessage != null) ...[
                  Text(
                    result.errorMessage!,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  serviceUnavailable
                      ? (widget.isTagalog
                            ? 'Subukan muli kapag naibalik na ng administrator ang verification service.'
                            : 'Please try again after an administrator restores the verification service.')
                      : (widget.isTagalog
                            ? 'Subukan muli gamit ang malinaw at kumpletong dokumento.'
                            : 'Please try again with a clear and complete document.'),
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(widget.isTagalog ? 'Sige' : 'OK'),
            ),
          ],
        );
      },
    );
  }

  String _formatFieldName(String fieldName) {
    // Convert field names to user-friendly format
    final formatted = fieldName.replaceAll('_', ' ').toLowerCase();
    final words = formatted.split(' ');

    return words
        .map((word) {
          if (word.length <= 3) return word.toUpperCase();
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  void _removeGodparent(int index) {
    setState(() {
      for (final controller in _additionalGodparents[index].values) {
        controller.dispose();
      }
      _additionalGodparents.removeAt(index);
    });
  }

  void _showBookingRestrictionsAlert() {
    // Define sacraments that have same-time blocking
    final timeBlockingSacraments = [
      SacramentType.baptism,
      SacramentType.wedding,
      SacramentType.confirmation,
      SacramentType.funeral,
    ];

    final hasTimeBlocking = timeBlockingSacraments.contains(
      widget.sacramentType,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                widget.isTagalog
                    ? 'Impormasyon sa Booking'
                    : 'Booking Information',
                style: const TextStyle(color: Colors.blue),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isTagalog
                      ? 'Mga Patakaran sa Booking:'
                      : 'Booking Rules:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                // Date blocking rule
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.isTagalog
                                  ? '2-3 Araw na Paghaharang'
                                  : '2-3 Day Blocking',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.isTagalog
                            ? 'Kapag gumawa ka ng booking, ang susunod na 2-3 araw ay hindi available para sa iba.'
                            : 'When you make a booking, the next 2-3 days become unavailable for others.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Time blocking rule (only for specific sacraments)
                if (hasTimeBlocking) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.isTagalog
                                    ? 'Pag-block ng Oras'
                                    : 'Time Blocking',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isTagalog
                              ? 'Ang sacrament na ito ay hindi pwedeng mag-book sa parehong oras na iba pang sacrament sa parehong araw.'
                              : 'This sacrament cannot be booked at the same time as other sacraments on the same day.',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                Text(
                  widget.isTagalog
                      ? 'Mangyaring siguruhing ang iyong napiling petsa at oras ay available bago magpatuloy.'
                      : 'Please ensure your selected date and time are available before proceeding.',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(widget.isTagalog ? 'Naintindihan' : 'Understood'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAllRequirements() async {
    print('DEBUG: Starting to save all requirements');
    print('DEBUG: Total requirements: ${_data.requirements.length}');
    print('DEBUG: Uploaded images count: ${_uploadedRequirementImages.length}');
    print('DEBUG: Validation results count: ${_validationResults.length}');

    for (int i = 0; i < _data.requirements.length; i++) {
      final platformFile = _uploadedRequirementImages[i];
      final validationResult = _validationResults[i];

      print('DEBUG: Requirement $i - ${_data.requirements[i]}');
      print('DEBUG:   Platform file: ${platformFile?.name ?? 'null'}');
      print(
        'DEBUG:   Validation result: ${validationResult != null ? 'present' : 'null'}',
      );

      if (platformFile != null && validationResult != null) {
        try {
          print('DEBUG: Saving requirement ${_data.requirements[i]}');

          final requirementId = await FirebaseService.instance
              .saveSacramentRequirement(
                sacramentType: widget.sacramentType.name,
                requirementType: _data.requirements[i],
                documentFile: platformFile,
              );

          // Save validation result to Firebase
          await FirebaseService.instance.saveRequirementValidationResult(
            requirementId: requirementId,
            validationResult: validationResult,
          );

          print(
            'DEBUG: Successfully saved requirement ${_data.requirements[i]} with ID: $requirementId',
          );
        } catch (e) {
          print('DEBUG: Error saving requirement ${_data.requirements[i]}: $e');
          _showModalNotificationGlobal(
            context,
            widget.isTagalog
                ? 'Error sa pag-save ng requirement: ${_data.requirements[i]}'
                : 'Error saving requirement: ${_data.requirements[i]}',
            bgColor: Colors.red,
          );
        }
      } else {
        final certificateType = widget.sacramentType == SacramentType.wedding
            ? null
            : _certificateTypeForRequirement(_data.requirements[i]);
        final existingCertificate = certificateType == null
            ? null
            : _existingCertificateCopies[certificateType];
        if (existingCertificate != null) {
          try {
            final requirementId = await FirebaseService.instance
                .saveParishCertificateRequirement(
                  sacramentType: widget.sacramentType.name,
                  requirementType: _data.requirements[i],
                  certificateRequestId: existingCertificate['requestId']!,
                  certificateUrl: existingCertificate['url']!,
                  certificateName: existingCertificate['certificateName']!,
                );
            debugPrint(
              'Linked parish certificate to booking requirement $requirementId',
            );
            continue;
          } catch (error) {
            debugPrint(
              'Could not link parish certificate for ${_data.requirements[i]}: $error',
            );
            _showModalNotificationGlobal(
              context,
              widget.isTagalog
                  ? 'Hindi mai-link ang kasalukuyang sertipiko: ${_data.requirements[i]}'
                  : 'Could not link the existing certificate: ${_data.requirements[i]}',
              bgColor: Colors.red,
            );
          }
        }
        print('DEBUG: Skipping requirement ${_data.requirements[i]} - no upload or parish certificate');
      }
    }

    print('DEBUG: Finished saving all requirements');
  }

  List<Map<String, dynamic>> _requirementSubmissionStatuses() {
    final weddingDate = widget.sacramentType == SacramentType.wedding
        ? _parseDateString(_selectedScheduleDate())
        : null;
    final dueDate = weddingDate?.subtract(const Duration(days: 7));

    return _data.requirements.asMap().entries
        .where((entry) =>
            !entry.value.contains('Requirements:') &&
            !entry.value.contains('Kinakailangan:'))
        .map((entry) {
          final index = entry.key;
          final certificateType = widget.sacramentType == SacramentType.wedding
              ? null
              : _certificateTypeForRequirement(entry.value);
          final hasParishCertificate = certificateType != null &&
              _existingCertificateCopies.containsKey(certificateType);
          final status = _uploadedRequirementImages[index] != null
              ? 'uploaded'
              : hasParishCertificate
                  ? 'on_file'
                  : _requirementsToFollow.contains(index)
                      ? 'to_follow'
                      : 'pending';
          return <String, dynamic>{
            'name': entry.value,
            'status': status,
            if (status == 'to_follow' && dueDate != null)
              'dueDate': '${dueDate.year.toString().padLeft(4, '0')}-'
                  '${dueDate.month.toString().padLeft(2, '0')}-'
                  '${dueDate.day.toString().padLeft(2, '0')}',
          };
        })
        .toList(growable: false);
  }

  bool _hasWeddingParentInfoFor(String party) {
    final partyTerms = party == 'groom'
        ? const ['groom', 'husband', 'lalaki']
        : const ['bride', 'wife', 'babae'];
    const parentRoleTerms = ['father', 'mother', 'ama', 'ina'];
    final sectionsByField = <String, String>{};
    var activeSection = 'FORM INFORMATION';
    for (final field in _data.fields) {
      if (field.startsWith('[SECTION]')) {
        activeSection = field.replaceFirst('[SECTION]', '').trim();
        continue;
      }
      final section = _data.fieldDefinitions[field]?['section']
              ?.toString()
              .trim() ??
          '';
      if (section.isNotEmpty) activeSection = section;
      sectionsByField[field] = activeSection;
    }

    for (final entry in _controllers.entries) {
      if (entry.value.text.trim().isEmpty) continue;

      final definition = _data.fieldDefinitions[entry.key] ?? const {};
      final searchableText = [
        entry.key,
        definition['label']?.toString() ?? '',
        definition['section']?.toString() ?? '',
        sectionsByField[entry.key] ?? '',
      ].join(' ').toLowerCase();
      final hasParty =
          partyTerms.any((term) => searchableText.contains(term));
      final hasParentRole =
          parentRoleTerms.any((term) => searchableText.contains(term));
      final hasNamedParentField = searchableText.contains('parent') &&
          (searchableText.contains('name') ||
              searchableText.contains('pangalan'));

      if (hasParty && (hasParentRole || hasNamedParentField)) return true;
    }

    // Keep compatibility with the app's original Wedding field keys in case
    // a form definition omits party or parent labels from its metadata.
    final parentKeys = party == 'groom'
        ? const ['Groom Father Name', 'Groom Mother Name']
        : const ['Bride Father Name', 'Bride Mother Name'];
    return parentKeys.any(
      (key) => (_controllers[key]?.text.trim().isNotEmpty ?? false),
    );
  }

  Future<void> _submitForm() async {
    if (FirebaseService.instance.currentUid.isEmpty) {
      _showModalNotificationGlobal(
        context,
        widget.isTagalog
            ? 'Kailangan mag-login upang makapagsumite ng request.'
            : 'You must be signed in to submit a request.',
        bgColor: Colors.red,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final approvedForm = await FirebaseService.instance
          .getBookingFormDefinition(widget.sacramentType.bookingFormKey);
      if (approvedForm == null) {
        if (mounted) {
          setState(() {
            _formDefinitionError =
                'This form is not currently approved for booking.';
          });
          _showModalNotificationGlobal(
            context,
            widget.isTagalog
                ? 'Hindi kasalukuyang aprubado ang form na ito para sa booking.'
                : 'This form is not currently approved for booking.',
            bgColor: Colors.red,
          );
        }
        return;
      }

      // Parent validation for wedding form
      if (widget.sacramentType == SacramentType.wedding) {
        final missingParties = [
          if (!_hasWeddingParentInfoFor('groom'))
            widget.isTagalog ? 'lalaki' : 'groom',
          if (!_hasWeddingParentInfoFor('bride'))
            widget.isTagalog ? 'babae' : 'bride',
        ];

        if (missingParties.isNotEmpty) {
          _showModalNotificationGlobal(
            context,
            widget.isTagalog
                ? 'Kailangan ang pangalan ng kahit isang magulang para sa bawat ikakasal. Hindi nakita ang impormasyon para sa: ${missingParties.join(' at ')}.'
                : 'Enter at least one parent name for both the groom and bride. Parent information was not detected for: ${missingParties.join(' and ')}.',
            bgColor: Colors.red,
          );
          return;
        }
      }

      final selectedDate = _selectedScheduleDate();
      final selectedTime = _selectedScheduleTime();

      if (widget.sacramentType == SacramentType.confirmation &&
          (selectedDate.isEmpty || selectedTime.isEmpty)) {
        _showModalNotificationGlobal(
          context,
          widget.isTagalog
              ? 'Wala pang nakatakdang petsa o oras ng Kumpil sa database. Makipag-ugnayan sa opisina ng parokya.'
              : 'The Confirmation date or time is not configured in the database. Please contact the parish office.',
          bgColor: Colors.red,
        );
        return;
      }

      if (selectedDate.isNotEmpty) {
        final dateWarningMessage = _bookingDateWarningMessage(
          selectedDate,
          enforceLeadTime: widget.sacramentType != SacramentType.massIntention,
        );
        if (dateWarningMessage != null) {
          _showModalNotificationGlobal(
            context,
            dateWarningMessage,
            bgColor: Colors.red,
          );
          return;
        }
      }

      if (selectedDate.isNotEmpty && selectedTime.isNotEmpty) {
        if (await _isBlockedByMassSchedule(
          date: selectedDate,
          time: selectedTime,
        )) {
          _showMassScheduleBlockedMessage();
          return;
        }

        if (widget.sacramentType != SacramentType.massIntention) {
          final cacheKey = 'any|$selectedDate|$selectedTime';
          final cached = _slotTakenCache[cacheKey];
          final isTaken =
              cached ??
              (await FirebaseService.instance
                      .checkSchedulingConflictWithFunction(
                        sacramentType: widget.sacramentType.label(
                          widget.isTagalog,
                        ),
                        date: selectedDate,
                        time: selectedTime,
                      ))
                  .hasConflict;
          _slotTakenCache[cacheKey] = isTaken;

          if (isTaken) {
            _showModalNotificationGlobal(
              context,
              widget.isTagalog
                  ? 'Ang napiling petsa at oras ay naka-book na. Pumili ng iba.'
                  : 'The selected date and time is already booked. Please choose another.',
              bgColor: Colors.red,
            );
            return;
          }
        }
      }

      if (widget.sacramentType == SacramentType.massIntention) {
        final date =
            _controllers['Date of Mass (Petsa ng Misa)']?.text.trim() ?? '';
        final time =
            _controllers['Time of Mass (Oras ng Misa)']?.text.trim() ?? '';

        if (date.isNotEmpty && time.isNotEmpty) {
          final pastTimeWarning = _massIntentionPastTimeWarning(date, time);
          if (pastTimeWarning != null) {
            _showModalNotificationGlobal(
              context,
              pastTimeWarning,
              bgColor: Colors.red,
            );
            return;
          }

        }
      }

      final fieldValues = _controllers.map(
        (key, controller) => MapEntry(key, controller.text.trim()),
      );

      if (widget.sacramentType == SacramentType.houseBlessing) {
        fieldValues.remove('Priest Name');
        fieldValues.remove("Priest's Name");
        fieldValues.remove('Registration - Priest\'s Name');
      }
      if (widget.sacramentType == SacramentType.massIntention) {
        fieldValues.removeWhere((key, _) => _isDonationArNumberField(key));
      }

      final requirementStatuses = _requirementSubmissionStatuses();
      if (widget.sacramentType == SacramentType.wedding &&
          requirementStatuses.any((item) => item['status'] == 'pending')) {
        _showModalNotificationGlobal(
          context,
          widget.isTagalog
              ? 'Para sa bawat requirement ng kasal, mag-upload ng dokumento o piliin ang “Ipapasa Pa”.'
              : 'For each wedding requirement, upload the document or select “To Follow”.',
          bgColor: Colors.red,
        );
        return;
      }

      final additionalGodparents = _additionalGodparents
          .map(
            (godparent) => godparent.map(
              (field, controller) => MapEntry(field, controller.text.trim()),
            ),
          )
          .toList();

      try {
        final bookingDetails = {
          'fields': fieldValues,
          'additionalGodparents': additionalGodparents,
          if (requirementStatuses.isNotEmpty)
            'requiredDocuments': requirementStatuses,
        };
        if (_usesDatabasePaymentOptions) {
          final option = _selectedPaymentOption;
          if (option == null) {
            throw Exception('Choose a fee before submitting.');
          }
          final selectedAddons = _paymentOptions
              .where((fee) => fee.isAddon && _selectedFeeAddonIds.contains(fee.id))
              .toList(growable: false);
          final totalAmount = option.amount + selectedAddons.fold<double>(
            0,
            (total, addon) => total + addon.amount,
          );
          final addonBreakdown = selectedAddons
              .map((addon) => {
                    'id': addon.id,
                    'name': addon.label,
                    'price': addon.amount,
                  })
              .toList(growable: false);
          final feeBreakdown = {
            'total': totalAmount,
            'currency': 'PHP',
            'paymentOptionId': option.id,
            'paymentOption': option.label,
            'baseAmount': option.amount,
            if (addonBreakdown.isNotEmpty) 'addons': addonBreakdown,
          };
          await FirebaseService.instance.submitBooking(
            sacramentType: widget.sacramentType.label(widget.isTagalog),
            details: {
              ...bookingDetails,
              'paymentOption': {
                'id': option.id,
                'label': option.label,
                'amount': option.amount,
              },
              'selectedAddons': addonBreakdown,
              'totalAmount': totalAmount,
            },
            feeBreakdown: feeBreakdown,
          );
        } else {
          await FirebaseService.instance.submitBooking(
            sacramentType: widget.sacramentType.label(widget.isTagalog),
            details: bookingDetails,
          );
        }

        _showModalNotificationGlobal(
          context,
          widget.isTagalog
              ? '${_data.title} naipadala! Hintayin ang aprubasyon ng admin bago magbayad.'
              : '${_data.title} submitted! Please wait for admin approval before proceeding to payment.',
          bgColor: ParishColors.greenSuccess,
        );

        // Save all uploaded requirements after successful booking creation
        await _saveAllRequirements();

        // Reset form after submit
        _formKey.currentState!.reset();
        for (final controller in _controllers.values) {
          controller.clear();
        }
        for (final godparent in _additionalGodparents) {
          for (final controller in godparent.values) {
            controller.clear();
          }
        }
        if (mounted) {
          setState(() {
            _uploadedRequirementImages.clear();
            _validationResults.clear();
            _requirementsToFollow.clear();
          });
        }
      } catch (e) {
        // Enhanced error handling to show scheduling conflict errors clearly
        String errorMessage = e.toString();
        if (errorMessage.contains('already occupied') ||
            errorMessage.contains('conflict')) {
          // This is a scheduling conflict error - show it with the conflict alert style
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => AlertDialog(
              title: Text(
                widget.isTagalog ? 'Saklaw na Itinakda' : 'Schedule Occupied',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              content: Text(
                widget.isTagalog
                    ? 'Ang oras na ito ay nakasaklaw na.\n\nAng napiling petsa at oras ay nakikipagtagpo sa iba pang aprubadong o naghihintay na booking.\n\nMangyaring pumili ng iba pang available na oras.'
                    : 'This schedule is already occupied.\n\nThe selected date and time conflicts with another approved or pending booking.\n\nPlease choose another available schedule.',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.isTagalog ? 'OK' : 'OK'),
                ),
              ],
            ),
          );
          return;
        }

        // For other errors, show the generic error message
        _showModalNotificationGlobal(
          context,
          widget.isTagalog
              ? 'Hindi maipadala ang form. Pakisubukang muli. ($errorMessage)'
              : 'Unable to submit the form. Please try again. ($errorMessage)',
          bgColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildRequirementReminder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 13,
            height: 1.35,
            color: Colors.black87,
          ),
          children: const [
            TextSpan(
              text: 'Reminder: ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: 'Please submit all required documents, including their hardcopies, to the parish office at least ',
            ),
            TextSpan(
              text: 'one week before the scheduled sacrament',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: '. Uploading the documents through the app '),
            TextSpan(
              text: 'does not',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: ' replace the submission of their hardcopies. '),
            TextSpan(
              text: 'All required hardcopy documents must still be submitted to the parish office.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String requirement, int index) {
    // Check if this is a separator/header (Groom Requirements: or Bride Requirements:)
    final isSeparator =
        requirement.contains('Requirements:') ||
        requirement.contains('Kinakailangan:');

    if (isSeparator) {
      // Return as a header/separator
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade300),
          ),
          child: Text(
            requirement,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Reuse a matching issued certificate from this parishioner's own records.
    final certificateType = widget.sacramentType == SacramentType.wedding
        ? null
        : _certificateTypeForRequirement(requirement);
    final existingCertificate = certificateType == null
        ? null
        : _existingCertificateCopies[certificateType];
    final isSatisfiedByParishRecord = existingCertificate != null;
    final isCheckingParishRecords =
        certificateType != null && _certificateCopiesLoading;

    // Regular requirement item with upload functionality
    final isUploaded = _uploadedRequirementImages[index] != null;
    final file = _uploadedRequirementImages[index];
    final isValidating = _isValidatingDocuments[index] ?? false;
    final validationResult = _validationResults[index];
    final fileName = isUploaded
        ? file!.name
        : _requirementsToFollow.contains(index)
            ? (widget.isTagalog ? 'Ipapasa bago ang takdang araw' : 'Marked to follow')
            : (widget.isTagalog ? 'Walang file na napili' : 'No file selected');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
              color: isSatisfiedByParishRecord
                  ? Colors.green.shade50
                  : isUploaded
                      ? Colors.blue.shade50
                      : Colors.grey.shade50,
            ),
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('• ', style: TextStyle(fontSize: 18)),
                          Expanded(
                            child: Text(
                              requirement,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (isSatisfiedByParishRecord)
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Already available in church records',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      else if (isCheckingParishRecords)
                        const Text(
                          'Checking church records…',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        )
                      else
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: isUploaded
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (!isSatisfiedByParishRecord &&
                    !isUploaded &&
                    widget.sacramentType == SacramentType.wedding)
                    OutlinedButton(
                      onPressed: isValidating
                          ? null
                          : () => setState(() {
                              if (!_requirementsToFollow.remove(index)) {
                                _requirementsToFollow.add(index);
                              }
                            }),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 9,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        _requirementsToFollow.contains(index)
                            ? (widget.isTagalog ? 'Pipiliin' : 'To Follow ✓')
                            : (widget.isTagalog ? 'Ipapasa Pa' : 'To Follow'),
                      ),
                    ),
                if (!isSatisfiedByParishRecord)
                  ElevatedButton.icon(
                  onPressed: isValidating || isCheckingParishRecords
                      ? null
                      : () => _uploadRequirementImage(index),
                  icon: isValidating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          isUploaded ? Icons.edit : Icons.upload_file,
                          size: 18,
                        ),
                    label: Text(
                      isValidating
                        ? (widget.isTagalog
                              ? 'Nagva-Validate...'
                              : 'Validating...')
                        : isUploaded
                        ? (widget.isTagalog ? 'Baguhin' : 'Edit')
                        : (widget.isTagalog ? 'Upload' : 'Upload'),
                    ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValidating
                        ? Colors.grey
                        : isUploaded
                        ? Colors.orange
                        : Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  ),
              ],
            ),
          ),

          // Show validation result if available
          if (validationResult != null) ...[
            const SizedBox(height: 8),
            DocumentValidationWidget(
              validationResult: validationResult,
              requirementType: _data.requirements[index],
              isTagalog: widget.isTagalog,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          textAlign: TextAlign.left,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedFirstCommunionForm(bool isTagalog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SCHOOL INFORMATION
        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG PAARALAN' : 'SCHOOL INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan ng Paaralan' : 'School Name',
          key: 'School Name (Pangalan ng Paaralan)',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan ng Paaralan' : 'School Address',
          key: 'School Address (Tirahan ng Paaralan)',
        ),
        _buildPhilippinePhoneField(
          isTagalog
              ? 'Numero ng Telepono ng Paaralan'
              : 'School Contact Number',
          key: 'School Contact Number (Numero ng Telepono)',
        ),
        _buildTextField(
          isTagalog ? 'Email ng Paaralan' : 'School Email Address',
          key: 'School Email Address (Email)',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan ng Principal' : 'Principal Name',
          key: 'Principal Name (Pangalan ng Principal)',
        ),

        // REQUEST DETAILS
        _buildSectionHeader(
          isTagalog ? 'DETALYE NG KAHILINGAN' : 'REQUEST DETAILS',
        ),
        _buildDropdownField(
          isTagalog ? 'Bilang ng Mag-aaral' : 'Number of Students',
          ['1-10', '11-20', '21-30', '31-40', '41-50', '51-100', '100+'],
          key: 'Number of Students (Bilang ng Mag-aaral)',
        ),
        _buildDropdownField(isTagalog ? 'Baitang' : 'Grade Level', [
          'Grade 1',
          'Grade 2',
          'Grade 3',
          'Grade 4',
          'Grade 5',
          'Grade 6',
          'Grade 7',
          'Grade 8',
          'Grade 9',
          'Grade 10',
        ], key: 'Grade Level (Baitang)'),
        _buildDateField(
          isTagalog ? 'Petsa na Nais' : 'Preferred Date',
          key: 'Preferred Date (Petsa na Nais)',
          selectableDayPredicate: (d) =>
              _isSelectableFlexibleRangeBookingDate(d, 365),
        ),
        _buildTimeField(
          isTagalog ? 'Oras na Nais' : 'Preferred Time',
          key: 'Preferred Time (Oras na Nais)',
        ),
        _buildDateField(
          isTagalog ? 'Alternatibong Petsa' : 'Alternative Date',
          key: 'Alternative Date (Alternatibong Petsa)',
          selectableDayPredicate: (d) =>
              _isSelectableFlexibleRangeBookingDate(d, 365),
        ),

        // CONTACT PERSON
        _buildSectionHeader(isTagalog ? 'CONTACT PERSON' : 'CONTACT PERSON'),
        _buildTextField(
          isTagalog ? 'Pangalan ng Kontak' : 'Contact Person Name',
          key: 'Contact Person Name (Pangalan ng Kontak)',
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Numero ng Kontak' : 'Contact Person Number',
          key: 'Contact Person Number (Numero ng Kontak)',
        ),
        _buildTextField(
          isTagalog ? 'Email ng Kontak' : 'Contact Person Email',
          key: 'Contact Person Email (Email ng Kontak)',
        ),

        // ADDITIONAL INFORMATION
        _buildSectionHeader(
          isTagalog ? 'KARAGDAGANG IMPORMASYON' : 'ADDITIONAL INFORMATION',
        ),
        _buildTextField(
          isTagalog
              ? 'Espesyal na Kahilingan (Opsyonal)'
              : 'Special Requests (Optional)',
          key: 'Special Requests (Espesyal na Kahilingan)',
          required: false,
        ),
        _buildTextField(
          isTagalog
              ? 'Karagdagang Paalala (Opsyonal)'
              : 'Additional Notes (Optional)',
          key: 'Additional Notes (Karagdagang Paalala)',
          required: false,
        ),
      ],
    );
  }

  Widget _buildSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildSubSubHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label, {
    String? key,
    bool required = true,
    String? defaultValue,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    final fieldKey = key ?? label;
    _controllers.putIfAbsent(fieldKey, () => TextEditingController());

    if (defaultValue != null && _controllers[fieldKey]!.text.trim().isEmpty) {
      _controllers[fieldKey]!.text = defaultValue;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: _controllers[fieldKey],
        readOnly: readOnly,
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) {
          if (validator != null) {
            return validator(value);
          }
          if (!required) return null;
          if (value == null || value.isEmpty) {
            return widget.isTagalog
                ? 'Pakitiyak na punuin ang $label'
                : 'Please fill in $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPhilippinePhoneField(
    String label, {
    String? key,
    bool required = true,
  }) {
    return _buildTextField(
      label,
      key: key,
      required: required,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11),
      ],
      validator: (value) {
        final v = (value ?? '').trim();
        if (!required && v.isEmpty) return null;
        if (v.isEmpty) {
          return widget.isTagalog
              ? 'Pakitiyak na punuin ang $label'
              : 'Please fill in $label';
        }
        if (v.length != 11 || !v.startsWith('09')) {
          return widget.isTagalog
              ? 'Gumamit ng PH number format: 09XXXXXXXXX'
              : 'Use PH number format: 09XXXXXXXXX';
        }
        return null;
      },
    );
  }

  Widget _buildDropdownWithController(
    String label,
    TextEditingController controller,
    List<String> options, {
    bool required = true,
    String? defaultValue,
  }) {
    if (defaultValue != null && controller.text.trim().isEmpty) {
      controller.text = defaultValue;
    }

    final currentValue = controller.text.trim().isEmpty
        ? (defaultValue ?? options.first)
        : controller.text.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        initialValue: options.contains(currentValue) ? currentValue : null,
        items: options
            .map((o) => DropdownMenuItem<String>(value: o, child: Text(o)))
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            controller.text = v;
          });
        },
        validator: (v) {
          if (!required) return null;
          if (v == null || v.trim().isEmpty) {
            return widget.isTagalog
                ? 'Pakitiyak na pumili ng $label'
                : 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildGodparentAgeField(
    String label,
    TextEditingController controller, {
    required int minAge,
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: (value) {
          final v = (value ?? '').trim();
          if (!required && v.isEmpty) return null;
          if (v.isEmpty) {
            return widget.isTagalog
                ? 'Pakitiyak na punuin ang $label'
                : 'Please fill in $label';
          }
          final parsed = int.tryParse(v);
          if (parsed == null || parsed < minAge) {
            return widget.isTagalog
                ? 'Dapat $minAge pataas'
                : 'Must be $minAge and above';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildTimeField(
    String label, {
    String? key,
    bool required = true,
    List<TimeOfDay>? allowedTimes,
    bool disabled = false,
    bool dropdownOnly = false,
  }) {
    final fieldKey = key ?? label;
    _controllers.putIfAbsent(fieldKey, () => TextEditingController());

    // Mass Intention retains its existing Mass-schedule exception. All other
    // parish services and sacraments use the shared date-specific slots.
    final usesStandardBookingSlots =
        widget.sacramentType != SacramentType.massIntention;
    final isMassIntention =
        widget.sacramentType == SacramentType.massIntention;
    final selectedDate = _selectedScheduleDate();
    final baseAllowedTimes = isMassIntention
        ? _massIntentionAllowedTimesForSelectedDate()
        : allowedTimes ??
              (usesStandardBookingSlots ? _standardBookingTimeSlots() : null);
    final availableStandardSlots = selectedDate.isEmpty
        ? const <String>[]
        : _availableStandardSlotsByDate[selectedDate] ?? const <String>[];
    final effectiveAllowedTimes = !usesStandardBookingSlots ||
            baseAllowedTimes == null
        ? baseAllowedTimes
        : baseAllowedTimes
            .where(
              (time) => availableStandardSlots.contains(_formatTimeOfDay(time)),
            )
            .toList(growable: false);
    final availabilityLoading = usesStandardBookingSlots &&
        selectedDate.isNotEmpty &&
        _standardSlotAvailabilityLoadingDates.contains(selectedDate);

    if (dropdownOnly || isMassIntention || effectiveAllowedTimes != null) {
      final allowedValues = (effectiveAllowedTimes ?? const <TimeOfDay>[])
          .map(_formatTimeOfDay)
          .toList();
      final currentValue = _controllers[fieldKey]!.text;
      final selectedValue = allowedValues.contains(currentValue) ? currentValue : null;
      if (_controllers[fieldKey]!.text != selectedValue) {
        _controllers[fieldKey]!.text = selectedValue ?? '';
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          initialValue: selectedValue,
          hint: Text(
            allowedValues.isEmpty
                ? (selectedDate.isEmpty
                    ? (widget.isTagalog
                        ? 'Pumili muna ng petsa'
                        : 'Select a date first')
                    : availabilityLoading
                    ? (widget.isTagalog
                        ? 'Sinusuri ang available na oras...'
                        : 'Checking available times...')
                    : (widget.isTagalog
                        ? 'Wala nang available na oras'
                        : 'No times are available'))
                : (widget.isTagalog ? 'Pumili ng oras' : 'Select a time'),
          ),
          items: allowedValues.map((option) {
            return DropdownMenuItem<String>(value: option, child: Text(option));
          }).toList(),
          onChanged: disabled ||
                  (isMassIntention &&
                      (selectedDate.isEmpty || _massScheduleLoading)) ||
                  allowedValues.isEmpty
              ? null
              : (value) async {
                  if (value == null) return;
                  setState(() {
                    _controllers[fieldKey]!.text = value;
                  });
                  // Check for scheduling conflicts after time is selected from dropdown
                  await _checkSchedulingConflictOnSelection();
                },
          validator: (value) {
            if (!required) return null;
            if (value == null || value.isEmpty) {
              return widget.isTagalog
                  ? 'Pakitiyak na pumili ng $label'
                  : 'Please select $label';
            }
            return null;
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: _controllers[fieldKey],
        readOnly: true,
        enabled: !disabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(
            Icons.access_time,
            color: ParishColors.primaryBlue,
          ),
        ),
        onTap: disabled
            ? null
            : () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );

                if (picked != null && mounted) {
                  final isClosedHour = picked.hour >= 20 || picked.hour < 5;
                  if (isClosedHour) {
                    _showModalNotificationGlobal(
                      context,
                      widget.isTagalog
                          ? 'Sarado ang parokya sa napiling oras.'
                          : 'The parish is closed at the selected time.',
                      bgColor: Colors.red,
                    );
                    return;
                  }

                  final selectedDate = _selectedScheduleDate();
                  final pickedTime = _formatTimeOfDay(picked);
                  if (await _isBlockedByMassSchedule(
                    date: selectedDate,
                    time: pickedTime,
                  )) {
                    _showMassScheduleBlockedMessage();
                    return;
                  }

                  if (allowedTimes != null && allowedTimes.isNotEmpty) {
                    final isAllowed = allowedTimes.any(
                      (t) => t.hour == picked.hour && t.minute == picked.minute,
                    );
                    if (!isAllowed) {
                      _showModalNotificationGlobal(
                        context,
                        widget.isTagalog
                            ? 'Hindi valid ang oras para sa schedule.'
                            : 'Selected time is not valid for the parish schedule.',
                        bgColor: Colors.red,
                      );
                      return;
                    }
                  }
                  setState(() {
                    _controllers[fieldKey]!.text = pickedTime;
                  });

                  // Check for scheduling conflicts after time is selected
                  await _checkSchedulingConflictOnSelection();
                }
              },
        validator: (value) {
          if (!required) return null;
          if (value == null || value.isEmpty) {
            return widget.isTagalog
                ? 'Pakitiyak na punuin ang $label'
                : 'Please select time for $label';
          }
          return null;
        },
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    try {
      final localizations = MaterialLocalizations.of(context);
      return localizations.formatTimeOfDay(time, alwaysUse24HourFormat: false);
    } catch (_) {}
    // Fallback formatting if MaterialLocalizations is unavailable
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatAssistantDate(DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatMediumDate(date);
  }

  String _assistantDateValue(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _assistantPeriodForTime(String value) {
    final parsed = _parseTimeOfDay(value);
    if (parsed == null) return '';
    return parsed.hour < 12 ? 'AM' : 'PM';
  }

  Future<List<String>> _assistantCandidateTimesForDate(DateTime date) async {
    return _standardBookingTimeSlots()
        .where((time) =>
            widget.sacramentType != SacramentType.massIntention ||
            !_isPastMassIntentionTime(date, time))
        .map(_formatTimeOfDay)
        .toList(growable: false);
  }

  bool _isActiveBookingStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return const {
      'pending',
      'approved',
      'accepted',
      'confirmed',
      'paid',
    }.contains(normalized);
  }

  Set<String> _bookingDocumentDates(Map<String, dynamic> data) {
    final dates = <String>{};

    for (final key in ['date', 'bookingDate', 'scheduleDate', 'selectedDate']) {
      final topLevelDate = _normalizeAssistantDateValue(data[key]);
      if (topLevelDate != null) {
        dates.add(topLevelDate);
      }
    }

    final details = data['details'];
    if (details is Map) {
      final fields = details['fields'];
      if (fields is Map) {
        for (final fieldKey in _assistantScheduleDateKeysForBooking(data)) {
          final normalizedDate = _normalizeAssistantDateValue(fields[fieldKey]);
          if (normalizedDate != null) {
            dates.add(normalizedDate);
          }
        }
      }
    }

    return dates;
  }

  List<String> _assistantScheduleDateKeysForBooking(Map<String, dynamic> data) {
    final rawKey = (data['sacramentTypeKey'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final rawType = (data['sacramentType'] ?? '').toString().toLowerCase();
    final typeKey = rawKey.contains('baptism')
        ? 'baptism'
        : rawKey.contains('confirmation')
        ? 'confirmation'
        : rawKey.contains('wedding')
        ? 'wedding'
        : rawKey.contains('funeral')
        ? 'funeral'
        : rawKey.contains('house')
        ? 'house_blessing'
        : rawKey.contains('anointing')
        ? 'anointing'
        : rawKey.contains('mass')
        ? 'mass_intention'
        : rawKey.contains('communion')
        ? 'first_communion'
        : rawType.contains('baptism') || rawType.contains('binyag')
        ? 'baptism'
        : rawType.contains('confirmation') || rawType.contains('kumpil')
        ? 'confirmation'
        : rawType.contains('wedding') || rawType.contains('kasal')
        ? 'wedding'
        : rawType.contains('funeral') || rawType.contains('yumao')
        ? 'funeral'
        : rawType.contains('house')
        ? 'house_blessing'
        : rawType.contains('anointing') || rawType.contains('sakit')
        ? 'anointing'
        : rawType.contains('mass intention') || rawType.contains('intensyon')
        ? 'mass_intention'
        : rawType.contains('communion')
        ? 'first_communion'
        : '';

    return switch (typeKey) {
      'baptism' => ['Registration - Date of Baptism'],
      'confirmation' => ['Date of Confirmation (Petsa ng Kumpil)'],
      'wedding' => ['Date of Wedding'],
      'funeral' => ['Burial Date', 'Burial Date (Petsa ng Libing)'],
      'house_blessing' => [
        'Date of Blessing',
        'Date and Time of Blessing (Petsa at Oras ng Blessing)',
      ],
      'anointing' => ['Appointment Date', 'Date and Time (Petsa at Oras)'],
      'mass_intention' => [
        'Date of Mass (Petsa ng Misa)',
        'Date of Mass',
        'Mass Intention Date',
        'Date of Mass Intention',
      ],
      'first_communion' => [
        'Preferred Date (Petsa na Nais)',
        'Date of First Communion',
        'First Communion Date',
      ],
      _ => const [],
    };
  }

  String? _normalizeAssistantDateValue(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return _assistantDateValue(value.toDate());
    if (value is DateTime) return _assistantDateValue(value);

    final trimmed = value.toString().trim();
    if (trimmed.isEmpty) return null;

    final isoMatch = RegExp(r'\d{4}-\d{1,2}-\d{1,2}').firstMatch(trimmed);
    if (isoMatch != null) {
      final parsed = DateTime.tryParse(isoMatch.group(0)!);
      return parsed == null ? null : _assistantDateValue(parsed);
    }

    final slashMatch = RegExp(r'\d{1,2}/\d{1,2}/\d{4}').firstMatch(trimmed);
    if (slashMatch != null) {
      final parts = slashMatch.group(0)!.split('/');
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);
      if (month != null && day != null && year != null) {
        return _assistantDateValue(DateTime(year, month, day));
      }
    }

    return null;
  }

  Future<Set<String>?> _activeBookingDatesForAssistantMonth({
    required int month,
    required int year,
  }) async {
    // The calendar preload already retrieves and counts active bookings for the
    // next year. Reusing it prevents the assistant from reading both booking
    // collections a second time every time suggestions are opened.
    if (_bookingCountsLoaded) {
      final monthPrefix = '$year-${month.toString().padLeft(2, '0')}-';
      return _bookingCountCache.entries
          .where((entry) =>
              entry.key.startsWith(monthPrefix) && entry.value > 0)
          .map((entry) => entry.key)
          .toSet();
    }

    final bookedDates = <String>{};
    final monthPrefix = '$year-${month.toString().padLeft(2, '0')}-';

    Future<void> readCollection(String collection) async {
      try {
        Query<Map<String, dynamic>> query = FirebaseFirestore.instance
            .collection(collection);
        if (collection == 'bookings') {
          query = query.where(
            'status',
            whereIn: [
              'pending',
              'approved',
              'accepted',
              'confirmed',
              'paid',
              'Pending',
              'Approved',
              'Accepted',
              'Confirmed',
              'Paid',
            ],
          );
        }

        final snapshot = await query.get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final status = (data['status'] ?? 'pending').toString();
          if (!_isActiveBookingStatus(status)) continue;
          bookedDates.addAll(
            _bookingDocumentDates(
              data,
            ).where((date) => date.startsWith(monthPrefix)),
          );
        }
      } catch (e) {
        if (collection == 'bookings') {
          debugPrint(
            'AI Booking Assistant: direct bookings read failed, using availability fallback: $e',
          );
          rethrow;
        } else {
          debugPrint(
            'AI Booking Assistant: could not read $collection for recommendations: $e',
          );
        }
      }
    }

    try {
      // These independent reads have no reason to wait for each other.
      await Future.wait([
        readCollection('bookings'),
        readCollection('sacrament_requests'),
      ]);
    } catch (_) {
      return null;
    }

    return bookedDates;
  }

  Future<bool> _assistantDateHasAnyActiveBooking({
    required String date,
    required Set<String>? activeBookedDates,
  }) async {
    if (activeBookedDates != null) {
      return activeBookedDates.contains(date);
    }

    try {
      final availability = await FirebaseService.instance
          .getBookingAvailability(date: date);
      final bookedCount = (availability['bookedCount'] as num?)?.toInt() ?? 0;
      final status = (availability['status'] ?? '').toString().toLowerCase();
      return bookedCount > 0 || status == 'limited' || status == 'fully_booked';
    } catch (e) {
      debugPrint(
        'AI Booking Assistant: availability fallback failed for $date: $e',
      );
      return true;
    }
  }

  Future<int> _assistantActiveBookingCountForDate({
    required String date,
    required Set<String>? activeBookedDates,
  }) async {
    final cachedCount = _bookingCountCache[date];
    if (cachedCount != null) return cachedCount;

    try {
      final availability = await FirebaseService.instance
          .getBookingAvailability(date: date);
      return (availability['bookedCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint(
        'AI Booking Assistant: booking count fallback failed for $date: $e',
      );
      return activeBookedDates?.contains(date) == true ? 1 : 0;
    }
  }

  bool _matchesAssistantDayPreference(DateTime date, String preference) {
    if (preference == 'weekday') {
      return date.weekday >= DateTime.tuesday &&
          date.weekday <= DateTime.friday;
    }
    if (preference == 'weekend') {
      return date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday;
    }
    return date.weekday != DateTime.monday;
  }

  String _assistantTimePreferenceForTime(String value) {
    final parsed = _parseTimeOfDay(value);
    if (parsed == null) return 'any';
    if (parsed.hour < 12) return 'morning';
    if (parsed.hour < 17) return 'afternoon';
    return 'evening';
  }

  bool _matchesAssistantTimePreference(String time, String preference) {
    if (preference == 'any') return true;
    return _assistantTimePreferenceForTime(time) == preference;
  }

  int _assistantDateDistanceScore(DateTime date, String selectedDate) {
    final parsed = _normalizeAssistantDateValue(selectedDate);
    if (parsed == null) return 0;
    final selected = DateTime.tryParse(parsed);
    if (selected == null) return 0;
    final distance = date.difference(selected).inDays.abs();
    if (distance == 0) return -12;
    if (distance <= 3) return -8;
    if (distance <= 7) return -4;
    return 0;
  }

  List<String> _prioritizedAssistantTimes(
    List<String> times,
    String effectiveTimePreference,
  ) {
    final sorted = [...times];
    sorted.sort((a, b) {
      final aMatches = _matchesAssistantTimePreference(
        a,
        effectiveTimePreference,
      );
      final bMatches = _matchesAssistantTimePreference(
        b,
        effectiveTimePreference,
      );
      if (aMatches != bMatches) return aMatches ? -1 : 1;
      final aParsed = _parseTimeOfDay(a);
      final bParsed = _parseTimeOfDay(b);
      final aMinutes = aParsed == null ? 9999 : aParsed.hour * 60 + aParsed.minute;
      final bMinutes = bParsed == null ? 9999 : bParsed.hour * 60 + bParsed.minute;
      return aMinutes.compareTo(bMinutes);
    });
    return sorted;
  }

  List<_BookingAssistantSlot> _diverseAssistantSlots(
    List<_BookingAssistantSlot> candidates,
    int maxSlots,
  ) {
    final selected = <_BookingAssistantSlot>[];
    final usedDates = <String>{};

    for (final slot in candidates) {
      if (selected.length >= maxSlots) break;
      if (usedDates.add(slot.dateValue)) {
        selected.add(slot);
      }
    }

    for (final slot in candidates) {
      if (selected.length >= maxSlots) break;
      if (!selected.any(
        (selectedSlot) =>
            selectedSlot.dateValue == slot.dateValue &&
            selectedSlot.timeValue == slot.timeValue,
      )) {
        selected.add(slot);
      }
    }

    return selected;
  }

  Future<_BookingAssistantResult> _buildBookingAssistantResult({
    required int month,
    required int year,
    required String dayPreference,
    required String timePreference,
    Set<String> excludedDates = const {},
  }) async {
    final warnings = <String>[];
    final slots = <_BookingAssistantSlot>[];
    final sacramentTypeLabel = widget.sacramentType.label(widget.isTagalog);
    final selectedDate = _selectedScheduleDate();
    final selectedTime = _selectedScheduleTime();
    final effectiveTimePreference =
        timePreference == 'any' && selectedTime.isNotEmpty
        ? _assistantTimePreferenceForTime(selectedTime)
        : timePreference;
    final enforceLeadTime = widget.sacramentType != SacramentType.massIntention;

    if (selectedDate.isNotEmpty) {
      final dateWarning = _bookingDateWarningMessage(
        selectedDate,
        enforceLeadTime: enforceLeadTime,
      );
      if (dateWarning != null) {
        warnings.add(dateWarning);
      }
    }

    if (selectedDate.isNotEmpty && selectedTime.isNotEmpty) {
      if (await _isBlockedByMassSchedule(
        date: selectedDate,
        time: selectedTime,
      )) {
        warnings.add(
          widget.isTagalog
              ? 'Ang napiling schedule ay tumatama sa oras ng Misa.'
              : 'The selected schedule overlaps with a Mass schedule.',
        );
      } else if (widget.sacramentType != SacramentType.massIntention) {
        final conflict = await FirebaseService.instance
            .checkSchedulingConflictWithFunction(
              sacramentType: sacramentTypeLabel,
              date: selectedDate,
              time: selectedTime,
            );
        if (conflict.hasConflict) {
          warnings.add(
            widget.isTagalog
                ? 'Ang napiling schedule ay crowded o may conflict. Subukan ang mas maluwag na araw.'
                : 'The selected schedule is crowded or has a conflict. Consider a less busy day.',
          );
        }
      }
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstMonthDay = DateTime(year, month);
    final minimumLeadDays =
        widget.sacramentType == SacramentType.wedding ? 21 : 2;
    final firstAllowedDay = enforceLeadTime
        ? today.add(Duration(days: minimumLeadDays))
        : today;
    final searchStart = firstMonthDay.isBefore(firstAllowedDay)
        ? firstAllowedDay
        : firstMonthDay;
    final searchEnd = DateTime(year, month + 1, 0);
    if (searchStart.isAfter(searchEnd)) {
      warnings.add(
        widget.isTagalog
            ? 'Walang valid booking date sa napiling buwan. Pumili ng susunod na buwan.'
            : 'There are no valid booking dates in the selected month. Please choose a later month.',
      );
    }

    if (widget.sacramentType != SacramentType.massIntention &&
        !_bookingCountsLoaded) {
      await _bookingCountsLoadFuture;
    }

    final activeBookedDates = await _activeBookingDatesForAssistantMonth(
      month: month,
      year: year,
    );
    const maxRecommendedDates = 5;
    final recommendedDateValues = <String>{};

    for (
      var date = searchStart;
      !date.isAfter(searchEnd);
      date = date.add(const Duration(days: 1))
    ) {
      // A recommendation needs one viable time per date. Once we have enough
      // dates, checking the rest of the month only adds network latency.
      if (recommendedDateValues.length >= maxRecommendedDates) break;
      final dateValue = _assistantDateValue(date);
      if (excludedDates.contains(dateValue)) continue;
      if (!_matchesAssistantDayPreference(date, dayPreference)) continue;
      if (_bookingDateWarningMessage(
            dateValue,
            enforceLeadTime: enforceLeadTime,
          ) !=
          null) {
        continue;
      }

      final hasAnyBooking = await _assistantDateHasAnyActiveBooking(
        date: dateValue,
        activeBookedDates: activeBookedDates,
      );
      if (hasAnyBooking) {
        continue;
      }

      final candidateTimes = _prioritizedAssistantTimes(
        await _assistantCandidateTimesForDate(date),
        effectiveTimePreference,
      );
      for (final time in candidateTimes) {
        if (!_matchesAssistantTimePreference(time, effectiveTimePreference) &&
            candidateTimes.any(
              (candidateTime) => _matchesAssistantTimePreference(
                candidateTime,
                effectiveTimePreference,
              ),
            )) {
          continue;
        }
        if (widget.sacramentType != SacramentType.massIntention) {
          try {
            // The conflict function includes the Mass-schedule test. Keeping
            // it as the single remote validation avoids duplicate reads.
            final conflict = await FirebaseService.instance
                .checkSchedulingConflictWithFunction(
                  sacramentType: sacramentTypeLabel,
                  date: dateValue,
                  time: time,
                );
            if (conflict.hasConflict) continue;
          } catch (e) {
            debugPrint(
              'AI Booking Assistant: conflict check failed for $dateValue $time: $e',
            );
          }
        }

        final period = _assistantPeriodForTime(time);
        final preferenceText = effectiveTimePreference == 'any'
            ? ''
            : widget.isTagalog
            ? ' Tugma rin ito sa preferred time of day mo.'
            : ' It also matches your preferred time of day.';
        final dateText = selectedDate.isNotEmpty
            ? widget.isTagalog
                ? ' Isinaalang-alang din ang date na nasa form mo.'
                : ' It also considers the date currently in your form.'
            : '';
        final recommendation = widget.isTagalog
            ? 'Mataas na rekomendasyon: zero booking ang petsang ito at walang nakitang conflict.$preferenceText$dateText'
            : 'Highly recommended: this date has zero bookings and no detected conflicts.$preferenceText$dateText';

        slots.add(
          _BookingAssistantSlot(
            date: date,
            dateValue: dateValue,
            timeValue: time,
            bookingCount: 0,
            periodBookingCount: 0,
            period: period,
            recommendation: recommendation,
          ),
        );
        recommendedDateValues.add(dateValue);
        // Candidate times are ordered by the user's preference, so the first
        // valid one is the best slot for this date.
        break;
      }
    }

    slots.sort((a, b) {
      final byBookings = a.bookingCount.compareTo(b.bookingCount);
      if (byBookings != 0) return byBookings;
      final aTimeMatches = _matchesAssistantTimePreference(
        a.timeValue,
        effectiveTimePreference,
      );
      final bTimeMatches = _matchesAssistantTimePreference(
        b.timeValue,
        effectiveTimePreference,
      );
      if (aTimeMatches != bTimeMatches) return aTimeMatches ? -1 : 1;
      final bySelectedDate = _assistantDateDistanceScore(
        a.date,
        selectedDate,
      ).compareTo(_assistantDateDistanceScore(b.date, selectedDate));
      if (bySelectedDate != 0) return bySelectedDate;
      final byPeriod = a.periodBookingCount.compareTo(b.periodBookingCount);
      if (byPeriod != 0) return byPeriod;
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.timeValue.compareTo(b.timeValue);
    });

    final zeroBookingSlots = _diverseAssistantSlots(
      [...slots],
      maxRecommendedDates,
    );
    slots
      ..clear()
      ..addAll(zeroBookingSlots);

    if (slots.isEmpty) {
      warnings.add(
        widget.isTagalog
            ? 'Lahat ng petsa sa pinili mong range ay may booking na. Ipapakita ng AI ang mga araw na may pinakakaunting booking.'
            : 'All dates in your selected range already have bookings. The AI is showing the days with the fewest bookings.',
      );

      final fallbackSlots = <_BookingAssistantSlot>[];
      final fallbackDateValues = <String>{};

      for (
        var date = searchStart;
        !date.isAfter(searchEnd);
        date = date.add(const Duration(days: 1))
      ) {
        if (fallbackDateValues.length >= maxRecommendedDates) break;
        final dateValue = _assistantDateValue(date);
        if (excludedDates.contains(dateValue)) continue;
        if (!_matchesAssistantDayPreference(date, dayPreference)) continue;
        if (_bookingDateWarningMessage(
              dateValue,
              enforceLeadTime: enforceLeadTime,
            ) !=
            null) {
          continue;
        }

        final bookingCount = await _assistantActiveBookingCountForDate(
          date: dateValue,
          activeBookedDates: activeBookedDates,
        );
        if (bookingCount <= 0) continue;

        final candidateTimes = _prioritizedAssistantTimes(
          await _assistantCandidateTimesForDate(date),
          effectiveTimePreference,
        );
        for (final time in candidateTimes) {
          if (!_matchesAssistantTimePreference(time, effectiveTimePreference) &&
              candidateTimes.any(
                (candidateTime) => _matchesAssistantTimePreference(
                  candidateTime,
                  effectiveTimePreference,
                ),
              )) {
            continue;
          }
          if (widget.sacramentType != SacramentType.massIntention) {
            try {
              final conflict = await FirebaseService.instance
                  .checkSchedulingConflictWithFunction(
                    sacramentType: sacramentTypeLabel,
                    date: dateValue,
                    time: time,
                  );
              if (conflict.hasConflict) continue;
            } catch (e) {
              debugPrint(
                'AI Booking Assistant: conflict check failed for $dateValue $time: $e',
              );
            }
          }

          final period = _assistantPeriodForTime(time);
          final preferenceText = effectiveTimePreference == 'any'
              ? ''
              : widget.isTagalog
              ? ' Tugma rin ito sa preferred time of day mo.'
              : ' It also matches your preferred time of day.';
          final recommendation = widget.isTagalog
              ? 'Fallback recommendation: lahat ng napiling petsa ay may booking na, kaya ito ang mas magaan na araw na may $bookingCount booking lamang.$preferenceText'
              : 'Fallback recommendation: all preferred dates already have bookings, so this is a lighter day with only $bookingCount booking(s).$preferenceText';

          fallbackSlots.add(
            _BookingAssistantSlot(
              date: date,
              dateValue: dateValue,
              timeValue: time,
              bookingCount: bookingCount,
              periodBookingCount: bookingCount,
              period: period,
              recommendation: recommendation,
            ),
          );
          fallbackDateValues.add(dateValue);
          break;
        }
      }

      fallbackSlots.sort((a, b) {
        final byBookings = a.bookingCount.compareTo(b.bookingCount);
        if (byBookings != 0) return byBookings;
        final aTimeMatches = _matchesAssistantTimePreference(
          a.timeValue,
          effectiveTimePreference,
        );
        final bTimeMatches = _matchesAssistantTimePreference(
          b.timeValue,
          effectiveTimePreference,
        );
        if (aTimeMatches != bTimeMatches) return aTimeMatches ? -1 : 1;
        final bySelectedDate = _assistantDateDistanceScore(
          a.date,
          selectedDate,
        ).compareTo(_assistantDateDistanceScore(b.date, selectedDate));
        if (bySelectedDate != 0) return bySelectedDate;
        final byPeriod = a.periodBookingCount.compareTo(b.periodBookingCount);
        if (byPeriod != 0) return byPeriod;
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.timeValue.compareTo(b.timeValue);
      });

      slots.addAll(_diverseAssistantSlots(fallbackSlots, maxRecommendedDates));
    }

    slots.sort((a, b) {
      final byBookings = a.bookingCount.compareTo(b.bookingCount);
      if (byBookings != 0) return byBookings;
      final aTimeMatches = _matchesAssistantTimePreference(
        a.timeValue,
        effectiveTimePreference,
      );
      final bTimeMatches = _matchesAssistantTimePreference(
        b.timeValue,
        effectiveTimePreference,
      );
      if (aTimeMatches != bTimeMatches) return aTimeMatches ? -1 : 1;
      final bySelectedDate = _assistantDateDistanceScore(
        a.date,
        selectedDate,
      ).compareTo(_assistantDateDistanceScore(b.date, selectedDate));
      if (bySelectedDate != 0) return bySelectedDate;
      final byPeriod = a.periodBookingCount.compareTo(b.periodBookingCount);
      if (byPeriod != 0) return byPeriod;
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.timeValue.compareTo(b.timeValue);
    });

    return _BookingAssistantResult(
      bestSlot: slots.isEmpty ? null : slots.first,
      alternatives: slots.skip(1).take(maxRecommendedDates - 1).toList(),
      warnings: warnings,
    );
  }

  void _applyAssistantSlot(_BookingAssistantSlot slot) {
    final dateKeys = _selectedScheduleDateKeys();
    final timeKeys = _selectedScheduleTimeKeys();
    if (dateKeys.isEmpty || timeKeys.isEmpty) return;

    String formFieldKey(List<String> keys) => keys.firstWhere(
      (key) => _data.fields.contains(key),
      orElse: () => keys.first,
    );

    final dateKey = formFieldKey(dateKeys);
    final timeKey = formFieldKey(timeKeys);

    final sundayBaptism =
        widget.sacramentType == SacramentType.baptism &&
        slot.date.weekday == DateTime.sunday;
    setState(() {
      _controllers.putIfAbsent(dateKey, TextEditingController.new).text =
          slot.dateValue;
      _controllers.putIfAbsent(timeKey, TextEditingController.new).text =
          slot.timeValue;
      if (widget.sacramentType == SacramentType.baptism) {
        _isSundayBaptismDate = sundayBaptism;
        _sundayBaptismTime = sundayBaptism ? slot.timeValue : null;
      }
      if (widget.sacramentType == SacramentType.confirmation) {
        final day = _weekdayName(slot.date);
        _controllers.putIfAbsent('Day (Araw)', () => TextEditingController());
        _controllers['Day (Araw)']!.text = day;
        _dropdownValues['Day (Araw)'] = day;
      }
      if (widget.sacramentType == SacramentType.massIntention) {
        _controllers[timeKey]!.text = slot.timeValue;
      }
    });
    _refreshStandardSlotAvailability(slot.dateValue);
  }

  void _showAIBookingAssistantModal({bool manual = false}) {
    if (!mounted || _isBookingAssistantOpen) return;
    if (!_supportsBookingAssistant()) return;
    if (!manual && _hasShownBookingAssistant) return;

    _hasShownBookingAssistant = true;
    _isBookingAssistantOpen = true;
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;
    String selectedDayPreference = 'any';
    String selectedTimePreference = _selectedScheduleTime().isNotEmpty
        ? _assistantTimePreferenceForTime(_selectedScheduleTime())
        : 'any';
    final excludedRecommendationDates = <String>{};
    Future<_BookingAssistantResult>? recommendationFuture;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void findRecommendations() {
              setDialogState(() {
                recommendationFuture = _buildBookingAssistantResult(
                  month: selectedMonth,
                  year: selectedYear,
                  dayPreference: selectedDayPreference,
                  timePreference: selectedTimePreference,
                  excludedDates: excludedRecommendationDates,
                );
              });
            }

            void generateAgain(_BookingAssistantResult result) {
              excludedRecommendationDates.addAll([
                if (result.bestSlot != null) result.bestSlot!.dateValue,
                ...result.alternatives.map((slot) => slot.dateValue),
              ]);
              setDialogState(() {
                recommendationFuture = _buildBookingAssistantResult(
                  month: selectedMonth,
                  year: selectedYear,
                  dayPreference: selectedDayPreference,
                  timePreference: selectedTimePreference,
                  excludedDates: excludedRecommendationDates,
                );
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: ParishColors.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isTagalog
                          ? 'AI Booking Assistant'
                          : 'AI Booking Assistant',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      widget.isTagalog
                          ? 'Anong buwan at taon mo planong mag-book?'
                          : 'What month and year are you planning to book?',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedMonth,
                            decoration: InputDecoration(
                              labelText: widget.isTagalog ? 'Buwan' : 'Month',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: List.generate(12, (index) {
                              final month = index + 1;
                              final label = MaterialLocalizations.of(
                                context,
                              ).formatMonthYear(DateTime(2026, month));
                              return DropdownMenuItem<int>(
                                value: month,
                                child: Text(label.split(' ').first),
                              );
                            }),
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedMonth = value;
                                recommendationFuture = null;
                                excludedRecommendationDates.clear();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: selectedYear,
                            decoration: InputDecoration(
                              labelText: widget.isTagalog ? 'Taon' : 'Year',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            items: List.generate(3, (index) {
                              final year = now.year + index;
                              return DropdownMenuItem<int>(
                                value: year,
                                child: Text('$year'),
                              );
                            }),
                            onChanged: (value) {
                              if (value == null) return;
                              setDialogState(() {
                                selectedYear = value;
                                recommendationFuture = null;
                                excludedRecommendationDates.clear();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDayPreference,
                      decoration: InputDecoration(
                        labelText: widget.isTagalog
                            ? 'Weekday o Weekend'
                            : 'Weekday or Weekend',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'any',
                          child: Text(
                            widget.isTagalog
                                ? 'Kahit weekday o weekend'
                                : 'Any day',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'weekday',
                          child: Text(
                            widget.isTagalog ? 'Weekdays' : 'Weekdays',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'weekend',
                          child: Text(widget.isTagalog ? 'Weekend' : 'Weekend'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedDayPreference = value;
                          recommendationFuture = null;
                          excludedRecommendationDates.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTimePreference,
                      decoration: InputDecoration(
                        labelText: widget.isTagalog
                            ? 'Preferred time'
                            : 'Preferred time',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'any',
                          child: Text(
                            widget.isTagalog ? 'Kahit anong oras' : 'Any time',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'morning',
                          child: Text(widget.isTagalog ? 'Umaga' : 'Morning'),
                        ),
                        DropdownMenuItem(
                          value: 'afternoon',
                          child: Text(
                            widget.isTagalog ? 'Hapon' : 'Afternoon',
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedTimePreference = value;
                          recommendationFuture = null;
                          excludedRecommendationDates.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: findRecommendations,
                        icon: const Icon(Icons.search),
                        label: Text(
                          widget.isTagalog
                              ? 'Maghanap ng Recommendations'
                              : 'Find Recommendations',
                        ),
                      ),
                    ),
                    if (recommendationFuture != null) ...[
                      const SizedBox(height: 14),
                      FutureBuilder<_BookingAssistantResult>(
                        future: recommendationFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  widget.isTagalog
                                      ? 'Sinusuri ang available dates, mas magaan na araw, Mass schedules, at conflicts...'
                                      : 'Analyzing available dates, lighter booked days, Mass schedules, and conflicts...',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            );
                          }

                          if (snapshot.hasError) {
                            return Text(
                              widget.isTagalog
                                  ? 'Hindi mabasa ang availability ngayon. Pakisubukang muli.'
                                  : 'Unable to read availability right now. Please try again.',
                            );
                          }

                          final result = snapshot.data;
                          final bestSlot = result?.bestSlot;
                          if (bestSlot == null) {
                            return Text(
                              widget.isTagalog
                                  ? 'Walang recommendation sa napiling buwan. Subukan ang ibang buwan o taon.'
                                  : 'No recommendation was found in the selected month. Try another month or year.',
                            );
                          }

                          void chooseSlot(_BookingAssistantSlot slot) {
                            _applyAssistantSlot(slot);
                            Navigator.of(dialogContext).pop();
                          }

                          return ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 360),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.isTagalog
                                        ? 'Pinakamagandang available date'
                                        : 'Best available date',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildAssistantSlotCard(
                                    bestSlot,
                                    highlight: true,
                                    onSelected: () => chooseSlot(bestSlot),
                                  ),
                                  if ((result?.warnings ?? []).isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.isTagalog
                                          ? 'Mga warning sa napili mo'
                                          : 'Warnings for your selected schedule',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...result!.warnings.map(
                                      (warning) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.orange,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text(warning)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  if ((result?.alternatives ?? [])
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      widget.isTagalog
                                          ? 'Ibang available dates'
                                          : 'Other available dates',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...result!.alternatives.map(
                                      (slot) => _buildAssistantSlotCard(
                                        slot,
                                        onSelected: () => chooseSlot(slot),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => generateAgain(result!),
                                      icon: const Icon(Icons.refresh),
                                      label: Text(
                                        widget.isTagalog
                                            ? 'Generate Again'
                                            : 'Generate Again',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(widget.isTagalog ? 'Close' : 'Close'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() => _isBookingAssistantOpen = false);
  }

  Widget _buildAssistantSlotCard(
    _BookingAssistantSlot slot, {
    bool highlight = false,
    VoidCallback? onSelected,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? ParishColors.primaryBlue : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatAssistantDate(slot.date)} at ${slot.timeValue}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(slot.recommendation),
          const SizedBox(height: 4),
          Text(
            widget.isTagalog
                ? '${slot.bookingCount} booking sa araw na ito, ${slot.periodBookingCount} sa ${slot.period}.'
                : '${slot.bookingCount} booking(s) on this date, ${slot.periodBookingCount} in the ${slot.period}.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          if (onSelected != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onSelected,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(widget.isTagalog ? 'Gamitin ito' : 'Use this'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;
    final extracted = RegExp(
      r'\b(\d{1,2}:\d{2}\s*(?:[AaPp][Mm])?)\b',
    ).firstMatch(raw)?.group(1);
    if (extracted == null) return null;

    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?$',
    ).firstMatch(extracted.trim());
    if (match == null) return null;

    int h = int.tryParse(match.group(1) ?? '') ?? -1;
    final int m = int.tryParse(match.group(2) ?? '') ?? -1;
    if (h < 0 || m < 0 || m > 59) return null;

    final ampm = (match.group(3) ?? '').toLowerCase();
    if (ampm.isNotEmpty) {
      if (h < 1 || h > 12) return null;
      if (ampm == 'am') {
        h = h == 12 ? 0 : h;
      } else {
        h = h == 12 ? 12 : h + 12;
      }
    }
    return TimeOfDay(hour: h, minute: m);
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isPastMassIntentionTime(DateTime date, TimeOfDay time) {
    final now = DateTime.now();
    if (!_isSameCalendarDay(date, now)) return false;

    final selectedMinutes = time.hour * 60 + time.minute;
    final currentMinutes = now.hour * 60 + now.minute;
    return selectedMinutes < currentMinutes;
  }

  String? _massIntentionPastTimeWarning(String date, String time) {
    if (widget.sacramentType != SacramentType.massIntention) return null;

    final parsedDate = DateTime.tryParse(date);
    final parsedTime = _parseTimeOfDay(time);
    if (parsedDate == null || parsedTime == null) return null;

    if (!_isPastMassIntentionTime(parsedDate, parsedTime)) return null;
    return widget.isTagalog
        ? 'Hindi na maaaring piliin ang oras na lumipas na para sa Mass Intention ngayon.'
        : 'You cannot select a Mass Intention time that has already passed today.';
  }

  List<TimeOfDay> _extractMassTimesFromText(String value) {
    final matches = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])\b',
    ).allMatches(value);
    final times = <TimeOfDay>[];

    for (final match in matches) {
      var hour = int.tryParse(match.group(1) ?? '');
      final minute = int.tryParse(match.group(2) ?? '00');
      final meridiem = (match.group(3) ?? '').toLowerCase();
      if (hour == null || minute == null || minute < 0 || minute > 59) {
        continue;
      }

      if (hour < 1 || hour > 12) continue;
      if (meridiem == 'am') {
        hour = hour == 12 ? 0 : hour;
      } else {
        hour = hour == 12 ? 12 : hour + 12;
      }

      final candidate = TimeOfDay(hour: hour, minute: minute);
      final exists = times.any(
        (item) =>
            item.hour == candidate.hour && item.minute == candidate.minute,
      );
      if (!exists) times.add(candidate);
    }

    times.sort(
      (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
    );
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

    const names = {
      DateTime.monday: ['monday', 'mon', 'lunes'],
      DateTime.tuesday: ['tuesday', 'tue', 'martes'],
      DateTime.wednesday: ['wednesday', 'wed', 'miyerkules'],
      DateTime.thursday: ['thursday', 'thu', 'huwebes'],
      DateTime.friday: ['friday', 'fri', 'biyernes'],
      DateTime.saturday: ['saturday', 'sat', 'sabado'],
      DateTime.sunday: ['sunday', 'sun', 'linggo'],
    };

    final mentionedDays = names.entries
        .where((entry) => entry.value.any((name) => text.contains(name)))
        .map((entry) => entry.key)
        .toSet();

    if (mentionedDays.isEmpty) return true;
    return mentionedDays.contains(weekday);
  }

  List<TimeOfDay> _massIntentionAllowedTimesForSelectedDate() {
    final dateValue = _selectedScheduleDate();
    final parsedDate = DateTime.tryParse(dateValue);
    if (parsedDate == null || _massScheduleTexts.isEmpty) return [];

    final times = <TimeOfDay>[];
    for (final scheduleText in _massScheduleTexts) {
      if (!_scheduleTextAppliesToDate(scheduleText, parsedDate)) continue;
      for (final time in _extractMassTimesFromText(scheduleText)) {
        if (_isPastMassIntentionTime(parsedDate, time)) continue;
        final exists = times.any(
          (item) => item.hour == time.hour && item.minute == time.minute,
        );
        if (!exists) times.add(time);
      }
    }

    times.sort(
      (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
    );
    return times;
  }

  Widget _buildCurrentMassScheduleList(bool isTagalog) {
    if (_massScheduleLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      );
    }

    if (_massScheduleTexts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          isTagalog
              ? 'Walang nakalistang Mass schedule sa database.'
              : 'No Mass schedule is currently listed in the database.',
          style: const TextStyle(color: ParishColors.textBlue900),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _massScheduleTexts.map((schedule) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.schedule,
                  size: 18,
                  color: ParishColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    schedule,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ParishColors.textBlue900,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<String?> _loadSundayBaptismTime(DateTime date) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      final massTimes = <TimeOfDay>[];
      for (final collection in ['mass_schedules', 'massSchedules']) {
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection(collection)
              .where('date', isEqualTo: dateStr)
              .get();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data['active'] == false) continue;
            final rawTime =
                (data['time'] ?? data['timeString'] ?? data['startTime'] ?? '')
                    .toString();
            final time = _parseTimeOfDay(rawTime);
            if (time != null) massTimes.add(time);
          }
        } catch (error) {
          debugPrint('Could not load Sunday baptism times from $collection: $error');
        }
      }

      if (massTimes.isEmpty) {
        final profile = await FirebaseFirestore.instance
            .collection('parish_profile')
            .doc('main')
            .get();
        if (profile.exists) {
          final scheduleTexts = _massScheduleTextsFromProfileData(
            profile.data() ?? const <String, dynamic>{},
          );
          for (final text in scheduleTexts) {
            final normalized = text.toLowerCase();
            if (!normalized.contains('sunday') &&
                !normalized.contains('linggo')) {
              continue;
            }
            final time = _parseTimeOfDay(text);
            if (time != null) massTimes.add(time);
          }
        }
      }

      if (massTimes.isEmpty) return null;

      massTimes.sort((a, b) {
        final aMinutes = a.hour * 60 + a.minute;
        final bMinutes = b.hour * 60 + b.minute;
        return aMinutes.compareTo(bMinutes);
      });

      final firstMass = massTimes.first;
      final nextHourMinutes = firstMass.hour * 60 + firstMass.minute + 60;
      if (nextHourMinutes >= 24 * 60) return null;
      final nextHour = TimeOfDay(
        hour: nextHourMinutes ~/ 60,
        minute: nextHourMinutes % 60,
      );
      return _formatTimeOfDay(nextHour);
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkSchedulingConflictOnSelection() async {
    // Confirmation uses the fixed date and time configured by the parish.
    // Keep those database values intact; submission validates the fixed slot.
    if (widget.sacramentType == SacramentType.confirmation) return;

    // Find date and time fields for current sacrament type
    String? dateFieldValue;
    String? timeFieldValue;

    // Get field keys based on sacrament type
    List<String> dateKeys = [];
    List<String> timeKeys = [];

    switch (widget.sacramentType) {
      case SacramentType.baptism:
        dateKeys = ['Registration - Date of Baptism'];
        timeKeys = ['Registration - Time of Baptism'];
        break;
      case SacramentType.confirmation:
        dateKeys = ['Date of Confirmation (Petsa ng Kumpil)'];
        timeKeys = ['Time (Oras)'];
        break;
      case SacramentType.wedding:
        dateKeys = ['Date of Wedding'];
        timeKeys = ['Time'];
        break;
      case SacramentType.funeral:
        dateKeys = ['Burial Date', 'Burial Date (Petsa ng Libing)'];
        timeKeys = ['Burial Time', 'Burial Time (Oras ng Libing)'];
        break;
      case SacramentType.houseBlessing:
        dateKeys = ['Date of Blessing'];
        timeKeys = ['Time of Blessing'];
        break;
      case SacramentType.anointing:
        dateKeys = ['Appointment Date'];
        timeKeys = ['Appointment Time'];
        break;
      case SacramentType.massIntention:
        dateKeys = [
          'Date of Mass (Petsa ng Misa)',
          'Date of Mass Intention',
          'Mass Intention Date',
        ];
        timeKeys = [
          'Time of Mass (Oras ng Misa)',
          'Time of Mass Intention',
          'Mass Intention Time',
        ];
        break;
      case SacramentType.firstCommunion:
        dateKeys = ['Date of First Communion', 'First Communion Date'];
        timeKeys = ['Time of First Communion', 'First Communion Time'];
        break;
      case SacramentType.renewalOfVows:
        dateKeys = _selectedScheduleDateKeys();
        timeKeys = _selectedScheduleTimeKeys();
        break;
    }

    dateKeys.addAll(_databaseFieldKeys('date'));
    timeKeys.addAll(_databaseFieldKeys('time'));

    // Find date and time field values
    for (final key in dateKeys) {
      if (_controllers.containsKey(key) && _controllers[key]!.text.isNotEmpty) {
        dateFieldValue = _controllers[key]!.text;
        debugPrint(
          '[CONFLICT CHECK] Found date field "$key" = "$dateFieldValue"',
        );
        break;
      }
    }

    for (final key in timeKeys) {
      if (_controllers.containsKey(key) && _controllers[key]!.text.isNotEmpty) {
        timeFieldValue = _controllers[key]!.text;
        debugPrint(
          '[CONFLICT CHECK] Found time field "$key" = "$timeFieldValue"',
        );
        break;
      }
    }

    // Debug: Show all available controllers
    debugPrint(
      '[CONFLICT CHECK] Available controllers: ${_controllers.keys.join(", ")}',
    );
    debugPrint('[CONFLICT CHECK] Sacrament type: ${widget.sacramentType}');
    debugPrint('[CONFLICT CHECK] Date keys to check: ${dateKeys.join(", ")}');
    debugPrint('[CONFLICT CHECK] Time keys to check: ${timeKeys.join(", ")}');

    // If we have both date and time, check for conflicts
    if (dateFieldValue != null && timeFieldValue != null && mounted) {
      try {
        if (await _isBlockedByMassSchedule(
          date: dateFieldValue,
          time: timeFieldValue,
        )) {
          if (mounted) {
            setState(_clearSelectedScheduleTime);
            _showMassScheduleBlockedMessage();
          }
          return;
        }

        final pastMassTimeWarning = _massIntentionPastTimeWarning(
          dateFieldValue,
          timeFieldValue,
        );
        if (pastMassTimeWarning != null) {
          if (mounted) {
            setState(_clearSelectedScheduleTime);
            _showModalNotificationGlobal(
              context,
              pastMassTimeWarning,
              bgColor: Colors.red,
            );
          }
          return;
        }

        final sacramentTypeLabel = widget.sacramentType.label(widget.isTagalog);

        debugPrint(
          '[CONFLICT CHECK] Checking conflict for: $sacramentTypeLabel on $dateFieldValue at $timeFieldValue',
        );

        final result = await FirebaseService.instance
            .checkSchedulingConflictWithFunction(
              sacramentType: sacramentTypeLabel,
              date: dateFieldValue,
              time: timeFieldValue,
            );

        debugPrint(
          '[CONFLICT CHECK] Result: hasConflict=${result.hasConflict}, message=${result.errorMessage}',
        );

        if (mounted && result.hasConflict) {
          debugPrint('[CONFLICT CHECK] Showing conflict alert!');
          setState(_clearSelectedScheduleTime);
          await _refreshStandardSlotAvailability(dateFieldValue);
          // Show alert with the three-line message
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => AlertDialog(
              title: Text(
                widget.isTagalog ? 'Saklaw na Itinakda' : 'Schedule Occupied',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              content: Text(
                widget.isTagalog
                    ? 'Ang oras na ito ay nakasaklaw na.\n\nAng napiling petsa at oras ay nakikipagtagpo sa iba pang aprubadong o naghihintay na booking.\n\nMangyaring pumili ng iba pang available na oras.'
                    : 'This schedule is already occupied.\n\nThe selected date and time conflicts with another approved or pending booking.\n\nPlease choose another available schedule.',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(widget.isTagalog ? 'OK' : 'OK'),
                ),
              ],
            ),
          );
        } else if (mounted) {
          debugPrint('[CONFLICT CHECK] No conflict detected');
        }
      } catch (e) {
        debugPrint('[CONFLICT CHECK] Error checking scheduling conflict: $e');
      }
    } else {
      debugPrint(
        '[CONFLICT CHECK] Skipping check - date: $dateFieldValue, time: $timeFieldValue, mounted: $mounted',
      );
    }
  }

  DateTime? _parseDateString(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      final parts = dateStr.split(RegExp(r'[-\/.]'));
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final day = int.tryParse(parts[2]);
        if (year != null && month != null && day != null) {
          return DateTime(year, month, day);
        }
      }
      return null;
    }
  }

  String _weekdayName(DateTime date) {
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

  Widget _buildDateField(
    String label, {
    String? key,
    bool isBirthday = false,
    bool required = true,
    int? minDaysFromNow,
    int? maxDaysFromNow,
    bool Function(DateTime)? selectableDayPredicate,
  }) {
    final fieldKey = key ?? label;
    _controllers.putIfAbsent(fieldKey, () => TextEditingController());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextFormField(
        controller: _controllers[fieldKey],
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(
            Icons.calendar_today,
            color: ParishColors.primaryBlue,
          ),
        ),
        onTap: () async {
          final DateTime today = DateTime.now();
          final DateTime firstDate;
          final DateTime lastDate;
          DateTime initialDate;

          if (isBirthday) {
            firstDate = DateTime(1900);
            lastDate = today;
            initialDate = DateTime(today.year - 20);
          } else {
            final int minDays = minDaysFromNow ?? 0;
            final int maxDays = maxDaysFromNow ?? (365 * 2);
            firstDate = DateTime(
              today.year,
              today.month,
              today.day,
            ).add(Duration(days: minDays));
            lastDate = DateTime(
              today.year,
              today.month,
              today.day,
            ).add(Duration(days: maxDays));

            if (selectableDayPredicate != null &&
                widget.sacramentType != SacramentType.massIntention) {
              _bookingCountsLoaded = false;
              _bookingCountsLoadFuture = _preloadBookingCounts();
              final dialogFuture = showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Dialog(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Loading availability...'),
                      ],
                    ),
                  ),
                ),
              );

              await _bookingCountsLoadFuture;
              if (mounted && Navigator.canPop(context)) {
                Navigator.of(context).pop();
              }
              await dialogFuture;
              if (!mounted) return;
            }

            initialDate = firstDate;
            if (selectableDayPredicate != null) {
              var cursor = initialDate;
              while (!selectableDayPredicate(cursor) &&
                  !cursor.isAfter(lastDate)) {
                cursor = cursor.add(const Duration(days: 1));
              }
              if (cursor.isAfter(lastDate)) {
                _showModalNotificationGlobal(
                  context,
                  widget.isTagalog
                      ? 'Walang available na petsa sa kasalukuyang saklaw ng kalendaryo.'
                      : 'No available dates were found in the current calendar range.',
                  bgColor: Colors.red,
                );
                return;
              }
              initialDate = cursor;
            }
          }

          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            selectableDayPredicate: selectableDayPredicate,
          );

          if (picked != null) {
            final selectedDate =
                "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
            final dateWarning = _bookingDateWarningMessage(
              selectedDate,
              enforceLeadTime: !isBirthday,
            );
            if (!isBirthday && dateWarning != null) {
              _showModalNotificationGlobal(
                context,
                dateWarning,
                bgColor: Colors.red,
              );
              return;
            }
            if (widget.sacramentType == SacramentType.baptism &&
                _selectedScheduleDateKeys().contains(fieldKey)) {
              final bool sunday = picked.weekday == DateTime.sunday;
              String? sundayTime;
              if (sunday) {
                sundayTime = await _loadSundayBaptismTime(picked);
                if (sundayTime == null) {
                  _showModalNotificationGlobal(
                    context,
                    widget.isTagalog
                        ? 'Walang nakatalang Misa para sa Linggong ito. Pumili ng ibang petsa o makipag-ugnayan sa opisina ng parokya.'
                        : 'No Mass schedule is recorded for this Sunday. Choose another date or contact the parish office.',
                    bgColor: Colors.red,
                  );
                  return;
                }
              }
              setState(() {
                _controllers[fieldKey]!.text = selectedDate;
                _isSundayBaptismDate = sunday;
                _sundayBaptismTime = sundayTime;
                // Safely set the time controller without forcing a null
                final scheduleTimeField = _selectedScheduleTimeKeys()
                    .firstWhere(
                      _data.fields.contains,
                      orElse: () => 'Registration - Time of Baptism',
                    );
                _controllers.putIfAbsent(
                  scheduleTimeField,
                  TextEditingController.new,
                ).text = sunday ? (sundayTime ?? '') : '';
              });
              await _refreshStandardSlotAvailability(selectedDate);
              // Check for scheduling conflicts after date is selected
              await _checkSchedulingConflictOnSelection();
            } else {
              setState(() {
                _controllers[fieldKey]!.text = selectedDate;
                if (fieldKey == 'Date of Confirmation (Petsa ng Kumpil)') {
                  final day = _weekdayName(picked);
                  _controllers.putIfAbsent(
                    'Day (Araw)',
                    () => TextEditingController(),
                  );
                  _controllers['Day (Araw)']!.text = day;
                  _dropdownValues['Day (Araw)'] = day;
                }
                if (fieldKey == 'Date of Mass (Petsa ng Misa)') {
                  _controllers['Time of Mass (Oras ng Misa)']?.clear();
                }
              });
              if (_selectedScheduleDateKeys().contains(fieldKey)) {
                await _refreshStandardSlotAvailability(selectedDate);
              }
              // Check for scheduling conflicts after date is selected
              await _checkSchedulingConflictOnSelection();
            }
          }
        },
        validator: (value) {
          if (!required) return null;
          if (value == null || value.isEmpty) {
            return widget.isTagalog
                ? 'Pakitiyak na punuin ang $label'
                : 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildNumberField(
    String label, {
    String? key,
    int min = 0,
    int max = 100,
    bool required = true,
  }) {
    final fieldKey = key ?? label;
    _controllers.putIfAbsent(fieldKey, () => TextEditingController());
    final List<String> options = List.generate(
      (max - min) + 1,
      (index) => (min + index).toString(),
    );

    String? currentVal = _dropdownValues[fieldKey];
    if (currentVal == null &&
        _controllers[fieldKey]!.text.isNotEmpty &&
        options.contains(_controllers[fieldKey]!.text)) {
      currentVal = _controllers[fieldKey]!.text;
    }
    if (currentVal != null && !options.contains(currentVal)) {
      currentVal = null;
      _dropdownValues.remove(fieldKey);
      _controllers[fieldKey]!.clear();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        initialValue: currentVal,
        items: options.map((option) {
          return DropdownMenuItem<String>(value: option, child: Text(option));
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _dropdownValues[fieldKey] = value;
              _controllers.putIfAbsent(fieldKey, () => TextEditingController());
              _controllers[fieldKey]!.text = value;
            });
          }
        },
        validator: (value) {
          if (!required) return null;
          if (value == null || value.isEmpty) {
            return widget.isTagalog
                ? 'Pakitiyak na punuin ang $label'
                : 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> options, {
    String? key,
    bool required = true,
    String? defaultValue,
  }) {
    final fieldKey = key ?? label;
    if (defaultValue != null && _dropdownValues[fieldKey] == null) {
      _dropdownValues[fieldKey] = defaultValue;
      _controllers.putIfAbsent(fieldKey, () => TextEditingController());
      _controllers[fieldKey]!.text = defaultValue;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        initialValue: _dropdownValues[fieldKey],
        items: options.map((option) {
          return DropdownMenuItem<String>(value: option, child: Text(option));
        }).toList(),
        onChanged: (value) {
          setState(() {
            _dropdownValues[fieldKey] = value!;
            _controllers.putIfAbsent(fieldKey, () => TextEditingController());
            _controllers[fieldKey]!.text = value;
          });
        },
        validator: (value) {
          if (!required) return null;
          if (value == null || value.isEmpty) {
            return widget.isTagalog
                ? 'Pakitiyak na pumili ng $label'
                : 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildGodparentField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return widget.isTagalog
                ? 'Pakitiyak na punuin ang $label'
                : 'Please fill in $label';
          }
          return null;
        },
      ),
    );
  }

  /// Show recommendations dialog with available slots

  @override
  Widget build(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);
    final isTagalog = widget.isTagalog;
    final title = widget.sacramentType.label(isTagalog);

    // Show loading indicator while checking age eligibility.
    if (_ageLoading) {
      return Scaffold(
        backgroundColor: ParishColors.bgBlue50,
        appBar: AppBar(
          centerTitle: true,
          title: Text(title),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(40, 40),
            ),
          ),
          backgroundColor: ParishColors.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error message if user is not eligible
    if (_ageEligibilityError != null) {
      return Scaffold(
        backgroundColor: ParishColors.bgBlue50,
        appBar: AppBar(
          centerTitle: true,
          title: Text(title),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 24),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(40, 40),
            ),
          ),
          backgroundColor: ParishColors.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          child: ParishResponsiveScaffold(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.lock_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _ageEligibilityError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_userAge != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              '${isTagalog ? 'Iyong Edad' : 'Your Age'}: $_userAge',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isTagalog ? 'Bumalik' : 'Go Back',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_usesDatabasePaymentOptions && !_paymentOptionChosen) {
      return Scaffold(
        backgroundColor: ParishColors.bgBlue50,
        appBar: AppBar(
          centerTitle: true,
          title: Text(isTagalog ? 'Pumili ng Bayarin' : 'Choose a Fee'),
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          backgroundColor: ParishColors.primaryBlue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              margin: const EdgeInsets.all(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isTagalog
                          ? 'Pumili ng bayarin bago punan ang form.'
                          : 'Choose a fee before filling in the form.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if (_paymentOptionsLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_paymentOptionsError != null)
                      Column(
                        children: [
                          Text(
                            _paymentOptionsError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loadServicePaymentOptions,
                            icon: const Icon(Icons.refresh),
                            label: Text(isTagalog ? 'Subukan muli' : 'Retry'),
                          ),
                        ],
                      )
                    else
                      ..._paymentOptions.map((option) {
                        if (option.isAddon) {
                          final checked = _selectedFeeAddonIds.contains(option.id);
                          return Card(
                            child: CheckboxListTile(
                              value: checked,
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _selectedFeeAddonIds.add(option.id);
                                } else {
                                  _selectedFeeAddonIds.remove(option.id);
                                }
                              }),
                              title: Text(option.label),
                              subtitle: Text(
                                'Add PHP ${option.amount.toStringAsFixed(2)}',
                              ),
                            ),
                          );
                        }
                        final selected = _selectedPaymentOption?.id == option.id;
                        return Card(
                          color: selected ? Colors.blue.shade50 : Colors.white,
                          child: RadioListTile<String>(
                            value: option.id,
                            groupValue: _selectedPaymentOption?.id,
                            onChanged: (_) => setState(
                              () => _selectedPaymentOption = option,
                            ),
                            title: Text(option.label),
                            subtitle: Text(
                              '₱${option.amount.toStringAsFixed(2)}'
                              '${option.description.isEmpty ? '' : '\n${option.description}'}',
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _selectedPaymentOption == null
                          ? null
                          : () => setState(() => _paymentOptionChosen = true),
                      child: Text(isTagalog ? 'Magpatuloy sa Form' : 'Continue to Form'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_supportsBookingAssistant() &&
        !_hasShownBookingAssistant &&
        !_massScheduleLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAIBookingAssistantModal();
      });
    }

    return Scaffold(
      backgroundColor: ParishColors.bgBlue50,
      appBar: AppBar(
        centerTitle: true,
        title: Text(title),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white, size: 24),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(40, 40),
          ),
        ),
        backgroundColor: ParishColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          if (_supportsBookingAssistant())
            IconButton(
              tooltip: isTagalog
                  ? 'AI Booking Assistant'
                  : 'AI Booking Assistant',
              onPressed: () => _showAIBookingAssistantModal(manual: true),
              icon: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 22,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: ParishResponsiveScaffold(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 20,
            0,
            isMobile ? 16 : 20,
            isMobile ? 16 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 14 : 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedPaymentOption != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            '${isTagalog ? 'Napiling bayarin' : 'Selected fees'}: '
                            '$_selectedPaymentLabel · PHP ${_selectedPaymentTotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      if (_data.requirements.isNotEmpty) ...[
                        Text(
                          isTagalog
                              ? 'Mga Kinakailangang Dokumento / Requirements'
                              : 'Required Documents / Requirements',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        _buildRequirementReminder(),
                        const SizedBox(height: 10),
                        if (widget.sacramentType ==
                                SacramentType.houseBlessing ||
                            widget.sacramentType == SacramentType.anointing ||
                            widget.sacramentType == SacramentType.massIntention)
                          ..._data.requirements.map((r) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '• ',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                  Expanded(child: Text(r)),
                                ],
                              ),
                            );
                          })
                        else
                          ..._data.requirements.asMap().entries.map((entry) {
                            final index = entry.key;
                            final requirement = entry.value;
                            return _buildRequirementItem(requirement, index);
                          }),
                        const SizedBox(height: 18),
                      ],
                      if (_formDefinitionLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_formDefinitionError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            _formDefinitionError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      else
                        _buildDatabaseDrivenForm(isTagalog),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ||
                                  _formDefinitionLoading ||
                                  _formDefinitionError != null
                              ? null
                              : _submitForm,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      isTagalog
                                          ? 'Isinusumite...'
                                          : 'Submitting...',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                )
                              : Text(
                                  // Booking-first flow: always submit the form.
                                  (isTagalog
                                      ? 'Isumite Ang Form'
                                      : 'Submit Form'),
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds every user-visible form control from `booking_requirements.fields`.
  /// The field names remain the submission keys, so existing booking, schedule,
  /// eligibility, and document-validation processes continue to use them.
  Widget _buildDatabaseDrivenForm(bool isTagalog) {
    final sections = <String, List<Widget>>{};
    var activeSection = isTagalog ? 'IMPORMASYON NG FORM' : 'FORM INFORMATION';
    var confirmationReminderAdded = false;
    final confirmationScheduleFields = widget.sacramentType ==
            SacramentType.confirmation
        ? {
            ..._selectedScheduleDateKeys(),
            ..._selectedScheduleTimeKeys(),
          }
        : const <String>{};

    for (final field in _data.fields) {
      if (field.startsWith('[SECTION]')) {
        final section = field.replaceFirst('[SECTION]', '').trim();
        if (section.isNotEmpty) activeSection = section;
        continue;
      }

      final definition = _data.fieldDefinitions[field] ?? const {};
      final section = (definition['section'] ?? '').toString().trim();
      if (section.isNotEmpty) activeSection = section;

      if (confirmationScheduleFields.contains(field)) {
        if (!confirmationReminderAdded) {
          sections
              .putIfAbsent(
                isTagalog ? 'ISKEDYUL NG KUMPIL' : 'CONFIRMATION SCHEDULE',
                () => <Widget>[],
              )
              .add(_buildConfirmationScheduleReminder(isTagalog));
          confirmationReminderAdded = true;
        }
        continue;
      }

      sections
          .putIfAbsent(activeSection, () => <Widget>[])
          .add(_buildDatabaseField(field, definition));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.entries
          .map(
            (entry) => _buildDatabaseSection(
              title: entry.key,
              fields: entry.value,
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildConfirmationScheduleReminder(bool isTagalog) {
    final rawDate = _selectedScheduleDate();
    final parsedDate = _parseDateString(rawDate);
    final rawTime = _selectedScheduleTime();
    final parsedTime = _parseTimeOfDay(rawTime);
    final dateText = parsedDate == null
        ? (isTagalog ? 'Hindi pa nakatakda' : 'Not scheduled')
        : MaterialLocalizations.of(context).formatMediumDate(parsedDate);
    final timeText = parsedTime == null
        ? (isTagalog ? 'Hindi pa nakatakda' : 'Not scheduled')
        : _formatTimeOfDay(parsedTime);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.bgBlue50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderBlue100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: ParishColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTagalog
                      ? 'Nakatakda na ang iskedyul ng Kumpil.'
                      : 'The Confirmation schedule is fixed by the parish.',
                  style: const TextStyle(
                    color: ParishColors.textBlue900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isTagalog ? 'Petsa: $dateText' : 'Date: $dateText',
            style: const TextStyle(color: ParishColors.textBlue900),
          ),
          const SizedBox(height: 4),
          Text(
            isTagalog ? 'Oras: $timeText' : 'Time: $timeText',
            style: const TextStyle(color: ParishColors.textBlue900),
          ),
        ],
      ),
    );
  }

  /// Previews OCR matches first. The form is mutated only after the user
  /// explicitly confirms the proposed values in the review dialog.
  Future<bool> _reviewAndAutoFillOcrData(
    DocumentValidationResult result,
    int requirementIndex,
  ) async {
    final data = result.extractedData;
    final proposed = <String, String>{};
    // Every supported requirement can contribute OCR values. Values are only
    // offered for empty, semantically matching fields below, so a document
    // never overwrites information the parishioner has already entered.
    final requirement = _data.requirements[requirementIndex].toLowerCase();
    final subject = requirement.contains('groom')
        ? 'groom'
        : requirement.contains('bride')
        ? 'bride'
        : '';

    String value(String key) => (data[key] ?? '').toString().trim();

    String? findField(bool Function(String normalized) matches) {
      for (final key in _controllers.keys) {
        if (matches(key.toLowerCase())) return key;
      }
      return null;
    }

    bool isDateValue(String candidate) =>
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(candidate) &&
        DateTime.tryParse(candidate) != null;

    bool isNameValue(String candidate) {
      if (candidate.length < 2 || candidate.length > 100) return false;
      if (RegExp(r'\d|@|https?://', caseSensitive: false).hasMatch(candidate)) {
        return false;
      }
      return RegExp(r"^[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .,'-]*$").hasMatch(candidate);
    }

    bool isTextValue(String candidate) =>
        candidate.length >= 2 &&
        candidate.length <= 160 &&
        !RegExp(r'https?://|\b(?:certificate|registry)\s*(?:no|number)\b',
                caseSensitive: false)
            .hasMatch(candidate);

    bool canUseInField(String fieldKey, String candidate) {
      final definition = _data.fieldDefinitions[fieldKey] ?? const {};
      final type = (definition['type'] ?? '').toString().toLowerCase();
      final options = definition['options'] is List
          ? (definition['options'] as List)
              .map((option) => option.toString().trim())
              .where((option) => option.isNotEmpty)
              .toList(growable: false)
          : const <String>[];
      if ((type == 'select' || type == 'dropdown') && options.isNotEmpty) {
        return options.any(
          (option) => option.toLowerCase() == candidate.toLowerCase(),
        );
      }
      return type != 'time' && !fieldKey.toLowerCase().contains('time');
    }

    String valueForField(String fieldKey, String candidate) {
      final definition = _data.fieldDefinitions[fieldKey] ?? const {};
      final options = definition['options'] is List
          ? (definition['options'] as List)
              .map((option) => option.toString().trim())
              .toList(growable: false)
          : const <String>[];
      return options.firstWhere(
        (option) => option.toLowerCase() == candidate.toLowerCase(),
        orElse: () => candidate,
      );
    }

    void apply(
      String extractedKey,
      bool Function(String normalized) matches, {
      bool preferCertificateSubject = false,
      bool Function(String value)? isValid,
    }) {
      final extracted = value(extractedKey);
      if (extracted.isEmpty || !(isValid?.call(extracted) ?? isTextValue(extracted))) {
        return;
      }
      final key = preferCertificateSubject && subject.isNotEmpty
          ? (findField((field) => field.contains(subject) && matches(field)) ??
              findField(matches))
          : findField(matches);
      if (key == null) return;
      final controller = _controllers[key];
      if (controller != null &&
          controller.text.trim().isEmpty &&
          canUseInField(key, extracted)) {
        proposed[key] = valueForField(key, extracted);
      }
    }

    void applyName(String extractedKey, {String role = ''}) {
      final extracted = value(extractedKey);
      if (!isNameValue(extracted)) return;
      final parts = extracted.split(RegExp(r'\s+'));
      final first = parts.first;
      final surname = parts.length > 1 ? parts.last : '';
      final middle = parts.length > 2
          ? parts.sublist(1, parts.length - 1).join(' ')
          : '';

      for (final entry in _controllers.entries) {
        final field = entry.key.toLowerCase();
        final controller = entry.value;
        if (controller.text.trim().isNotEmpty ||
            !(field.contains('name') ||
                field.contains('pangalan') ||
                field.contains('first') ||
                field.contains('middle') ||
                field.contains('surname') ||
                field.contains('last name'))) {
          continue;
        }

        final hasOtherPersonRole = [
          'father', 'mother', 'ama', 'ina', 'godparent', 'ninong', 'ninang',
          'contact', 'spouse', 'asawa', 'witness', 'saksi',
        ].any(field.contains);
        if (role.isNotEmpty) {
          var roleMatches = field.contains(role);
          if (role == 'father') {
            roleMatches = field.contains('father') || field.contains('ama');
          } else if (role == 'mother') {
            roleMatches = field.contains('mother') || field.contains('ina');
          } else if (role == 'spouse') {
            roleMatches = field.contains('spouse') || field.contains('asawa');
          }
          if (!roleMatches) continue;
        } else if (hasOtherPersonRole) {
          continue;
        }

        String? mappedValue;
        if (field.contains('first')) {
          mappedValue = first;
        } else if (field.contains('middle')) {
          mappedValue = middle;
        } else if (field.contains('surname') || field.contains('last name')) {
          mappedValue = surname;
        } else if (field.contains('full') ||
            (!field.contains('first') &&
                !field.contains('middle') &&
                !field.contains('surname'))) {
          mappedValue = extracted;
        }

        if (mappedValue != null &&
            mappedValue.isNotEmpty &&
            canUseInField(entry.key, mappedValue)) {
          proposed[entry.key] = valueForField(entry.key, mappedValue);
        }
      }
    }

    void applySponsorNames() {
      final rawNames = data['sponsor_names'];
      if (rawNames is! Iterable) return;
      final names = rawNames
          .map((name) => name.toString().trim())
          .where(isNameValue)
          .toList(growable: false);
      if (names.isEmpty) return;

      // Sponsors are assigned in their certificate order, and only to fields
      // explicitly identified as a godparent/Ninong/Ninang name.  This keeps
      // a sponsor from being inserted into a parent or applicant field.
      final sponsorFields = _controllers.entries
          .where((entry) {
            final field = entry.key.toLowerCase();
            return entry.value.text.trim().isEmpty &&
                (field.contains('godparent') ||
                    field.contains('ninong') ||
                    field.contains('ninang') ||
                    field.contains('sponsor')) &&
                (field.contains('name') || field.contains('pangalan'));
          })
          .map((entry) => entry.key)
          .toList(growable: false);
      for (var index = 0;
          index < names.length && index < sponsorFields.length;
          index++) {
        proposed[sponsorFields[index]] = names[index];
      }
    }

    void applyListedNames(
      String extractedKey,
      bool Function(String field) matches,
    ) {
      final rawNames = data[extractedKey];
      final names = (rawNames is Iterable
              ? rawNames
              : rawNames is String
              ? rawNames.split(RegExp(r'\s*(?:,|;|\band\b|&)\s*'))
              : const <dynamic>[])
          .map((name) => name.toString().trim())
          .where(isNameValue)
          .toList(growable: false);
      if (names.isEmpty) return;
      final fields = _controllers.entries
          .where((entry) =>
              entry.value.text.trim().isEmpty && matches(entry.key.toLowerCase()))
          .map((entry) => entry.key)
          .toList(growable: false);
      for (var index = 0; index < names.length && index < fields.length; index++) {
        if (canUseInField(fields[index], names[index])) {
          proposed[fields[index]] = valueForField(fields[index], names[index]);
        }
      }
    }

    // Names are split only into name fields. Dates, addresses, and places
    // have their own independently validated mappings below.
    applyName('full_name', role: subject);
    applyName('father_name', role: 'father');
    applyName('mother_name', role: 'mother');
    applyName('spouse_name', role: 'spouse');
    applySponsorNames();
    apply('parent_names',
        (field) =>
            (field.contains('parent') || field.contains('magulang')) &&
            (field.contains('name') || field.contains('pangalan')),
        isValid: isTextValue);
    applyListedNames(
      'witness_names',
      (field) =>
          (field.contains('witness') || field.contains('saksi')) &&
          (field.contains('name') || field.contains('pangalan')),
    );
    apply('date_of_birth',
        (field) =>
            (field.contains('date') || field.contains('petsa')) &&
            (field.contains('birth') || field.contains('kapanganakan')),
        isValid: isDateValue);
    apply('place_of_birth',
        (field) =>
            (field.contains('place') || field.contains('lugar')) &&
            (field.contains('birth') || field.contains('kapanganakan')),
        isValid: isTextValue);
    apply('address',
        (field) => field.contains('address') || field.contains('tirahan'),
        isValid: isTextValue);
    apply('date_of_baptism',
        (field) =>
            !field.contains('registration') &&
            !field.contains('schedule') &&
            (field.contains('date') || field.contains('petsa') || field.contains('kailan')) &&
            (field.contains('baptism') || field.contains('binyag') || field.contains('nabinyag')),
        isValid: isDateValue);
    apply('place_of_baptism',
        (field) =>
            (field.contains('place') || field.contains('lugar') || field.contains('saan')) &&
            (field.contains('baptism') || field.contains('binyag') || field.contains('nabinyag')),
        isValid: isTextValue);
    apply('date_of_confirmation',
        (field) =>
            (field.contains('date') || field.contains('petsa')) &&
            (field.contains('confirmation') || field.contains('kumpil')),
        isValid: isDateValue);
    apply('date_of_marriage',
        (field) =>
            (field.contains('date') || field.contains('petsa')) &&
            (field.contains('marriage') || field.contains('wedding') || field.contains('kasal')),
        isValid: isDateValue);
    apply('date_of_death',
        (field) =>
            (field.contains('date') || field.contains('petsa')) &&
            (field.contains('death') || field.contains('kamatayan')),
        isValid: isDateValue);
    apply('place_of_death',
        (field) =>
            (field.contains('place') || field.contains('lugar')) &&
            (field.contains('death') || field.contains('kamatayan')),
        isValid: isTextValue);
    apply('cause_of_death',
        (field) =>
            (field.contains('cause') || field.contains('sanhi')) &&
            (field.contains('death') || field.contains('kamatayan')),
        isValid: isTextValue);
    apply('burial_date',
        (field) =>
            (field.contains('date') || field.contains('petsa')) &&
            (field.contains('burial') || field.contains('libing')),
        isValid: isDateValue);
    apply('burial_place',
        (field) =>
            (field.contains('place') || field.contains('lugar')) &&
            (field.contains('burial') || field.contains('libing')),
        isValid: isTextValue);
    apply('parish_name', (field) =>
        field.contains('parish') || field.contains('parokya') || field.contains('church'),
        isValid: isTextValue);
    apply('minister_of_baptism',
        (field) =>
            (field.contains('minister') || field.contains('reverend') || field.contains('priest')) &&
            (field.contains('baptism') || field.contains('binyag') || field.contains('nagbinyag')),
        isValid: isNameValue);

    if (!mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          widget.isTagalog
              ? 'Suriin ang Na-extract na Detalye'
              : 'Review Extracted Details',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isTagalog
                    ? 'Suriin ang lahat ng detalyeng nabasa mula sa ${_data.requirements[requirementIndex]}. Walang mababago sa form hangga\'t hindi mo ito kinukumpirma.'
                    : 'Review all details read from ${_data.requirements[requirementIndex]}. Nothing is added to the form until you confirm.',
              ),
              const SizedBox(height: 12),
              Text(
                widget.isTagalog
                    ? 'Mga field na pupunan'
                    : 'Fields to auto-fill',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              if (proposed.isEmpty)
                Text(
                  widget.isTagalog
                      ? 'Walang tugmang bakanteng field na ligtas na mapupunan.'
                      : 'No matching empty form fields can be safely auto-filled.',
                )
              else
                ...proposed.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${entry.key}: ${entry.value}'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              widget.isTagalog
                  ? 'Kanselahin / Huwag Auto-Fill'
                  : 'Cancel / Do Not Auto-Fill',
            ),
          ),
          FilledButton(
            onPressed: proposed.isEmpty
                ? null
                : () => Navigator.of(dialogContext).pop(true),
            child: Text(
              widget.isTagalog
                  ? 'Kumpirmahin at Auto-Fill'
                  : 'Confirm and Auto-Fill',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    setState(() {
      proposed.forEach((field, value) {
        final controller = _controllers[field];
        // Recheck the field just before writing, in case the form changed
        // while the review dialog was visible.
        if (controller != null && controller.text.trim().isEmpty) {
          controller.text = value;
        }
      });
    });
    return true;
  }

  String _formatOcrKey(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');

  List<TimeOfDay> _standardBookingTimeSlots() {
    final times = <TimeOfDay>[];
    final seen = <int>{};
    for (final entry in _data.fieldDefinitions.entries) {
      final fieldName = entry.key.toLowerCase();
      final definition = entry.value;
      final type = (definition['type'] ?? '').toString().toLowerCase();
      if (type != 'time' &&
          !fieldName.contains('time') &&
          !fieldName.contains('oras')) {
        continue;
      }
      for (final time in _configuredTimeOptions(definition)) {
        final minutes = time.hour * 60 + time.minute;
        if (seen.add(minutes)) times.add(time);
      }
    }
    return times;
  }

  List<TimeOfDay> _configuredTimeOptions(Map<String, dynamic> definition) {
    final options = definition['options'] is List
        ? definition['options']
        : _data.schedules['timeOptions'] ??
              _data.schedules['availableTimes'] ??
              _data.schedules['timeSlots'] ??
              _data.schedules['recommendedSlots'];
    if (options is! List) return const [];
    final times = <TimeOfDay>[];
    final seen = <int>{};
    for (final option in options) {
      final time = _parseTimeOfDay(option?.toString() ?? '');
      if (time == null) continue;
      final minutes = time.hour * 60 + time.minute;
      if (seen.add(minutes)) times.add(time);
    }
    return times;
  }

  Future<void> _refreshStandardSlotAvailability(String date) async {
    if (widget.sacramentType == SacramentType.massIntention ||
        date.isEmpty ||
        _standardSlotAvailabilityLoadingDates.contains(date)) {
      return;
    }

    if (mounted) {
      setState(() {
        _standardSlotAvailabilityLoadingDates.add(date);
      });
    } else {
      _standardSlotAvailabilityLoadingDates.add(date);
    }
    final allSlots = _standardBookingTimeSlots()
        .map(_formatTimeOfDay)
        .toSet();
    if (widget.sacramentType == SacramentType.baptism &&
        _isSundayBaptismDate) {
      final sundayTime = _parseTimeOfDay(_sundayBaptismTime ?? '');
      if (sundayTime != null) allSlots.add(_formatTimeOfDay(sundayTime));
    }
    if (allSlots.isEmpty) {
      if (mounted) {
        setState(() {
          _availableStandardSlotsByDate[date] = const [];
          _standardSlotAvailabilityLoadingDates.remove(date);
        });
      } else {
        _availableStandardSlotsByDate[date] = const [];
        _standardSlotAvailabilityLoadingDates.remove(date);
      }
      return;
    }
    try {
      final availableSlots = await FirebaseService.instance.getAvailableTimeSlots(
        date: date,
        allPossibleTimeSlots: allSlots.toList(growable: false),
      );
      if (!mounted || _selectedScheduleDate() != date) return;

      setState(() {
        _availableStandardSlotsByDate[date] = availableSlots;
        final selectedTime = _selectedScheduleTime();
        if (selectedTime.isNotEmpty &&
            !availableSlots.contains(selectedTime)) {
          _clearSelectedScheduleTime();
        }
      });
    } catch (e) {
      debugPrint('[BOOKING SLOTS] Could not load availability for $date: $e');
    } finally {
      if (mounted) {
        setState(() {
          _standardSlotAvailabilityLoadingDates.remove(date);
        });
      } else {
        _standardSlotAvailabilityLoadingDates.remove(date);
      }
    }
  }

  Widget _buildDatabaseSection({
    required String title,
    required List<Widget> fields,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 18),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ParishColors.textBlue900.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined, color: ParishColors.textBlue900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: ParishColors.textBlue900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...fields,
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseField(
    String field,
    Map<String, dynamic> definition,
  ) {
    final fieldText = '$field ${definition['label'] ?? ''}';
    final normalized = fieldText.toLowerCase();
    final normalizedWords = fieldText
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .toLowerCase();
    final isAgeField = RegExp(
      r'(^|[^a-z])(age|edad)([^a-z]|$)',
    ).hasMatch(normalizedWords);
    final fieldType = (definition['type'] ?? '').toString().toLowerCase();
    final required = _isDatabaseFieldRequired(field, definition);
    final label = (definition['label'] ?? field)
        .toString()
        .replaceAll(RegExp(r'\s*\*\s*$'), '')
        .replaceAll(RegExp(r'\s*\?\s*$'), '')
        .replaceAll(RegExp(r'\s*\(optional\)\s*', caseSensitive: false), '')
        .trim();

    if (fieldType == 'date' || normalized.contains('date')) {
          final isHistoricalDate =
              normalized.contains('birth') ||
              normalized.contains('kapanganakan') ||
              (widget.sacramentType == SacramentType.confirmation &&
                  (normalized.contains('baptiz') ||
                      normalized.contains('binyag'))) ||
              (widget.sacramentType == SacramentType.baptism &&
                  normalized.contains('marriage'));
          return _buildDateField(
            label,
            key: field,
            required: required,
            isBirthday: isHistoricalDate,
            selectableDayPredicate: isHistoricalDate
                ? null
                : widget.sacramentType == SacramentType.firstCommunion
                ? (date) => _isSelectableFlexibleRangeBookingDate(date, 365)
                : widget.sacramentType == SacramentType.massIntention
                ? _isSelectableMassIntentionDate
                : _isSelectableSameDayAmPmBookingDate,
          );
    }
    if (fieldType == 'time' ||
        normalized.contains('time') ||
        normalized.contains('oras')) {
      final isBaptismScheduleTime =
          widget.sacramentType == SacramentType.baptism &&
          _selectedScheduleTimeKeys().contains(field);
      final sundayTime = _parseTimeOfDay(_sundayBaptismTime ?? '');
      return _buildTimeField(
        label,
        key: field,
        required: required,
        allowedTimes: isBaptismScheduleTime && _isSundayBaptismDate
            ? (sundayTime == null ? const [] : [sundayTime])
            : _configuredTimeOptions(definition),
        disabled: (isBaptismScheduleTime && _isSundayBaptismDate) ||
            (widget.sacramentType == SacramentType.massIntention &&
                _selectedScheduleDate().isEmpty),
        dropdownOnly: true,
      );
    }
    if (fieldType == 'phone' ||
            fieldType == 'tel' ||
            normalized.contains('contact') ||
            normalized.contains('phone') ||
            normalized.contains('cell') ||
            normalized.contains('tel.')) {
          return _buildPhilippinePhoneField(label, key: field, required: required);
    }
    if (fieldType == 'number' || isAgeField) {
          final isBaptismParentAge =
              widget.sacramentType == SacramentType.baptism &&
              (normalized.contains('father') ||
                  normalized.contains('mother') ||
                  normalized.contains('ama') ||
                  normalized.contains('ina'));
          final isConfirmationCandidateAge =
              widget.sacramentType == SacramentType.confirmation &&
              isAgeField &&
              !normalized.contains('ninong') &&
              !normalized.contains('ninang');
          final minAge = isBaptismParentAge ||
                  normalized.contains('ninong') ||
                  normalized.contains('ninang')
              ? 18
              : (widget.sacramentType == SacramentType.renewalOfVows &&
                        isAgeField
                    ? 21
                    : widget.sacramentType == SacramentType.wedding &&
                          (normalized.contains('groom') ||
                              normalized.contains('bride'))
                    ? 21
                    : isConfirmationCandidateAge
                    ? 7
                    : 0);
          return _buildNumberField(
            label,
            key: field,
            min: minAge,
            required: required,
          );
    }
    final configuredOptions = definition['options'] is List
            ? (definition['options'] as List)
                  .map((option) => option.toString())
                  .where((option) => option.isNotEmpty)
                  .toList(growable: false)
            : const <String>[];
    if ((fieldType == 'select' || fieldType == 'dropdown') &&
            configuredOptions.isNotEmpty) {
          return _buildDropdownField(label, configuredOptions,
              key: field, required: required);
    }
    if (normalized.contains('gender') || normalized.contains('kasarian')) {
          return _buildDropdownField(label, const ['Male', 'Female'],
              key: field, required: required);
    }
    if (normalized.contains('marriage status') ||
            normalized.endsWith(' status') ||
            normalized.contains('civil status')) {
          return _buildDropdownField(label, const ['Single', 'Married', 'Widowed', 'Annulled'],
              key: field, required: required);
    }
    return _buildTextField(label, key: field, required: required);
  }

  bool _isDatabaseFieldRequired(
    String field,
    Map<String, dynamic> definition,
  ) {
    final fieldAndLabel = '$field ${definition['label'] ?? ''}'.toLowerCase();
    if (widget.sacramentType == SacramentType.baptism &&
        (fieldAndLabel.contains('father') || fieldAndLabel.contains('ama'))) {
      return false;
    }

    final validation = definition['validation'] is Map
        ? Map<String, dynamic>.from(definition['validation'] as Map)
        : const <String, dynamic>{};

    bool? parseFlag(dynamic value) {
      if (value is bool) return value;
      if (value is num && (value == 0 || value == 1)) return value == 1;
      if (value is String) {
        switch (value.trim().toLowerCase()) {
          case 'true':
          case 'yes':
          case '1':
            return true;
          case 'false':
          case 'no':
          case '0':
            return false;
        }
      }
      return null;
    }

    for (final source in [definition, validation]) {
      for (final key in ['required', 'isRequired', 'is_required']) {
        final flag = parseFlag(source[key]);
        if (flag != null) return flag;
      }
      for (final key in ['optional', 'isOptional', 'is_optional']) {
        final flag = parseFlag(source[key]);
        if (flag != null) return !flag;
      }
    }

    final label = '$field ${definition['label'] ?? ''}'.toLowerCase();
    return !RegExp(r'\boptional\b|\bopsyonal\b').hasMatch(label) &&
        !field.trimRight().endsWith('?');
  }

  Widget _buildDetailedBaptismForm(bool isTagalog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isTagalog ? 'TAONG MABABINYAGAN' : 'PERSON TO BE BAPTIZED',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan' : 'Name',
          key: 'Baptized Person - Name',
        ),
        _buildNumberField(
          isTagalog ? 'Edad' : 'Age',
          key: 'Baptized Person - Age',
        ),
        _buildDateField(
          isTagalog ? 'Petsa ng Kapanganakan' : 'Date of Birth',
          isBirthday: true,
          key: 'Baptized Person - Date of Birth',
        ),
        _buildTextField(
          isTagalog ? 'Lugar ng Kapanganakan' : 'Place of Birth',
          key: 'Baptized Person - Place of Birth',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Baptized Person - Address',
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Cell / Tel. No.' : 'Cell / Tel. No.',
          key: 'Baptized Person - Contact Number',
        ),

        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG MGA MAGULANG' : 'PARENTS INFORMATION',
        ),
        _buildSubHeader(isTagalog ? 'Ama' : 'Father'),
        _buildTextField(
          isTagalog ? 'Pangalan ng Ama' : 'Father\'s Name',
          key: 'Father - Name',
          required: false,
        ),
        _buildNumberField(
          isTagalog ? 'Edad' : 'Age',
          key: 'Father - Age',
          required: false,
          min: 18,
        ),
        _buildTextField(
          isTagalog ? 'Relihiyon' : 'Religion',
          key: 'Father - Religion',
          required: false,
          defaultValue: 'Catholic',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Father - Address',
          required: false,
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Cell / Tel. No.' : 'Cell / Tel. No.',
          key: 'Father - Contact Number',
          required: false,
        ),

        _buildSubHeader(isTagalog ? 'Ina' : 'Mother'),
        _buildTextField(
          isTagalog ? 'Pangalan ng Ina' : 'Mother\'s Name',
          key: 'Mother - Name',
          required: false,
        ),
        _buildNumberField(
          isTagalog ? 'Edad' : 'Age',
          key: 'Mother - Age',
          required: false,
          min: 18,
        ),
        _buildTextField(
          isTagalog ? 'Relihiyon' : 'Religion',
          key: 'Mother - Religion',
          required: false,
          defaultValue: 'Catholic',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Mother - Address',
          required: false,
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Cell / Tel. No.' : 'Cell / Tel. No.',
          key: 'Mother - Contact Number',
          required: false,
        ),

        _buildSectionHeader(
          isTagalog ? 'KALAGAYAN NG KASAL' : 'MARRIAGE STATUS',
        ),
        _buildDropdownField(
          isTagalog ? 'Katayuan ng Kasal' : 'Marriage Status',
          isTagalog
              ? ['Ikasal sa Simbahan', 'Sibil na Kasal', 'Hindi Ikasal']
              : ['Married in Church', 'Civil Marriage', 'Not Married'],
          key: 'Parents - Marriage Status',
        ),

        // 'Other Information' section removed per request
        _buildSectionHeader(
          isTagalog ? 'MGA NINONG MATERNO/PATERNO' : 'PRIMARY GODPARENTS',
        ),
        _buildSubSubHeader(
          isTagalog ? 'Unang Ninong/Ninang' : 'First Godparent',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan' : 'Name',
          key: 'Godparent 1 - Name',
        ),
        _buildNumberField(
          isTagalog ? 'Edad' : 'Age',
          key: 'Godparent 1 - Age',
          min: 18,
        ),
        _buildDropdownField(
          isTagalog ? 'Relihiyon' : 'Religion',
          [
            'Catholic',
            'Christian',
            'Iglesia ni Cristo',
            'Islam',
            'Prefer not to say',
          ],
          key: 'Godparent 1 - Religion',
          defaultValue: 'Prefer not to say',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Godparent 1 - Address',
        ),

        _buildSubSubHeader(
          isTagalog ? 'Ikalawang Ninong/Ninang' : 'Second Godparent',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan' : 'Name',
          key: 'Godparent 2 - Name',
        ),
        _buildNumberField(
          isTagalog ? 'Edad' : 'Age',
          key: 'Godparent 2 - Age',
          min: 18,
        ),
        _buildDropdownField(
          isTagalog ? 'Relihiyon' : 'Religion',
          [
            'Catholic',
            'Christian',
            'Iglesia ni Cristo',
            'Islam',
            'Prefer not to say',
          ],
          key: 'Godparent 2 - Religion',
          defaultValue: 'Prefer not to say',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Godparent 2 - Address',
        ),

        // Additional Godparents
        ..._additionalGodparents.asMap().entries.map((entry) {
          final index = entry.key;
          final godparent = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubSubHeader(
                    isTagalog
                        ? 'Karagdagang Ninong/Ninang ${index + 1}'
                        : 'Additional Godparent ${index + 1}',
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeGodparent(index),
                  ),
                ],
              ),
              _buildGodparentField(
                isTagalog ? 'Pangalan' : 'Name',
                godparent['Name']!,
              ),
              _buildGodparentAgeField(
                isTagalog ? 'Edad' : 'Age',
                godparent['Age']!,
                minAge: 18,
              ),
              _buildDropdownWithController(
                isTagalog ? 'Relihiyon' : 'Religion',
                godparent['Religion']!,
                [
                  'Catholic',
                  'Christian',
                  'Iglesia ni Cristo',
                  'Islam',
                  'Prefer not to say',
                ],
                defaultValue: 'Prefer not to say',
              ),
              _buildGodparentField(
                isTagalog ? 'Tirahan' : 'Address',
                godparent['Address']!,
              ),
            ],
          );
        }),

        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            onPressed: _addGodparent,
            icon: const Icon(Icons.add),
            label: Text(
              isTagalog ? 'Magdagdag ng Ninong/Ninang' : 'Add Godparent',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),

        _buildSectionHeader(
          isTagalog ? 'DETALYE NG PAGPAPATALA' : 'REGISTRATION DETAILS',
        ),
        _buildDateField(
          isTagalog ? 'Petsa ng Binyag' : 'Date of Baptism',
          key: 'Registration - Date of Baptism',
          selectableDayPredicate: _isSelectableSameDayAmPmBookingDate,
        ),
        _buildTimeField(
          isTagalog ? 'Oras ng Binyag' : 'Time of Baptism',
          key: 'Registration - Time of Baptism',
          allowedTimes: _isSundayBaptismDate
              ? [
                  _parseTimeOfDay(_sundayBaptismTime ?? ''),
                ].whereType<TimeOfDay>().toList()
              : null,
          disabled: _isSundayBaptismDate,
        ),
        _buildTextField(
          isTagalog ? 'Pangalan ng Pari' : 'Priest\'s Name',
          key: 'Registration - Priest\'s Name',
          defaultValue: _currentParishPriest.isNotEmpty ? _currentParishPriest : null,
        ),
        _buildTextField(
          isTagalog ? 'Pangalan ng Simbahan' : 'Church Name',
          key: 'Registration - Church Name',
          defaultValue: 'Sto. Rosario Parish Church',
          readOnly: true,
        ),
        _buildTextField(
          isTagalog ? 'Tirahan ng Simbahan' : 'Church Address',
          key: 'Registration - Church Address',
          defaultValue:
              'CAGAYAN VALLEY RD., MALIPAMPANG, SAN ILDEFONSO, BULACAN 3010',
          readOnly: true,
        ),
      ],
    );
  }

  Widget _buildDetailedFuneralForm(bool isTagalog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isTagalog
              ? 'IMPORMASYON NG NAMATAY'
              : 'PERSONAL INFORMATION (Deceased)',
        ),
        _buildTextField(
          isTagalog ? 'Full Name (Buong Pangalan)' : 'Full Name',
          key: 'Deceased - Full Name',
        ),
        _buildTextField(
          isTagalog ? 'Nickname (Palayaw)' : 'Nickname',
          key: 'Deceased - Nickname',
        ),
        _buildNumberField(
          isTagalog ? 'Age (Edad)' : 'Age',
          key: 'Deceased - Age',
        ),

        _buildSubHeader(isTagalog ? 'Kalagayan ng Kasal' : 'Civil Status'),
        _buildDropdownField(
          isTagalog ? 'Katayuan ng Civil' : 'Civil Status',
          isTagalog
              ? ['May Asawa', 'Balo', 'Dalaga', 'Binata', 'Bata']
              : [
                  'Married',
                  'Widowed',
                  'Single (Female)',
                  'Single (Male)',
                  'Minor',
                ],
          key: 'Deceased - Civil Status',
        ),

        _buildSubHeader(
          isTagalog ? 'Religion / Baptism Status' : 'Religion / Baptism Status',
        ),
        _buildDropdownField(
          isTagalog ? 'Binyagan?' : 'Baptized?',
          isTagalog
              ? ['Binyagan', 'Hindi Binyagan']
              : ['Baptized', 'Not Baptized'],
          key: 'Deceased - Baptism Status',
        ),

        _buildTextField(
          isTagalog ? 'Pangalan ng Asawa/Maybahay' : 'Spouse Name',
          key: 'Deceased - Spouse Name',
        ),
        _buildNumberField(
          isTagalog ? 'Bilang ng Anak' : 'Number of Children',
          max: 20,
          key: 'Deceased - Number of Children',
        ),

        _buildSubHeader(
          isTagalog
              ? 'Children Status (Katayuan ng mga Anak)'
              : 'Children Status',
        ),
        _buildDropdownField(
          isTagalog ? 'Status ng mga Anak' : 'Children Status',
          isTagalog
              ? ['Buhay', 'Hindi Buhay', 'Hiwalay']
              : ['Living', 'Deceased', 'Separated'],
          key: 'Deceased - Children Status',
        ),

        _buildTextField(
          isTagalog ? 'Pangalan ng Tatay' : 'Father\'s Name',
          key: 'Deceased - Father\'s Name',
          required: false,
        ),
        _buildTextField(
          isTagalog ? 'Pangalan ng Nanay' : 'Mother\'s Name',
          key: 'Deceased - Mother\'s Name',
          required: false,
        ),
        _buildDateField(
          isTagalog ? 'Petsa ng Kapanganakan' : 'Date of Birth',
          isBirthday: true,
          key: 'Deceased - Date of Birth',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Deceased - Address',
        ),
        _buildTextField(
          isTagalog ? 'Parokyang Kinabibilangan' : 'Parish Affiliation',
          key: 'Deceased - Parish Affiliation',
        ),

        _buildSectionHeader(
          isTagalog ? 'SACRAMENTS RECEIVED' : 'SACRAMENTS RECEIVED',
        ),
        _buildDropdownField(
          isTagalog ? 'Kumpisal (Confession)' : 'Confession',
          isTagalog ? ['Oo', 'Hindi'] : ['Yes', 'No'],
          key: 'Sacraments Received - Confession',
        ),
        _buildDropdownField(
          isTagalog ? 'Pagpapahid ng Langis' : 'Anointing of the Sick',
          isTagalog ? ['Oo', 'Hindi'] : ['Yes', 'No'],
          key: 'Sacraments Received - Anointing',
        ),
        _buildDropdownField(
          isTagalog ? 'Viatico' : 'Viatico (Last Sacrament)',
          isTagalog ? ['Oo', 'Hindi'] : ['Yes', 'No'],
          key: 'Sacraments Received - Viatico',
        ),
        _buildDropdownField(
          isTagalog ? 'Naglingkod sa Simbahan' : 'Church Service',
          isTagalog ? ['Oo', 'Hindi'] : ['Yes', 'No'],
          key: 'Church Service',
        ),

        _buildSectionHeader(
          isTagalog
              ? 'IMPORMASYON NG KAMATAYAN AT LIBING'
              : 'DEATH AND BURIAL INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Sanhi ng Kamatayan' : 'Cause of Death',
          key: 'Death - Cause',
        ),
        _buildDateField(
          isTagalog ? 'Petsa ng Kamatayan' : 'Date of Death',
          isBirthday: true,
          key: 'Death - Date',
        ),
        _buildTextField(
          isTagalog ? 'Lugar ng Kamatayan' : 'Place of Death',
          key: 'Death - Place',
        ),

        _buildSubHeader(
          isTagalog ? 'Impormasyon ng Libing' : 'Burial Information',
        ),
        _buildDateField(
          isTagalog ? 'Petsa ng Libing' : 'Burial Date',
          key: 'Burial Date',
          selectableDayPredicate: _isSelectableSameDayAmPmBookingDate,
        ),
        _buildTextField(
          isTagalog ? 'Araw ng Libing' : 'Burial Day',
          key: 'Burial Day',
        ),
        _buildTimeField(
          isTagalog ? 'Oras ng Libing' : 'Burial Time',
          key: 'Burial Time',
        ),
        _buildTextField(
          isTagalog ? 'Lugar ng Libing' : 'Burial Place',
          key: 'Burial Place',
        ),

        _buildSubHeader(isTagalog ? 'Mga Kinakailangan' : 'Requirements'),
        _buildDropdownField(
          isTagalog ? 'Burial Permit (Pahintulot sa Libing)' : 'Burial Permit',
          isTagalog ? ['Meron', 'Wala'] : ['Present', 'Absent'],
          key: 'Requirements - Burial Permit',
        ),
        _buildDropdownField(
          isTagalog ? 'Sertipiko ng Kamatayan' : 'Death Certificate',
          isTagalog ? ['Meron', 'Wala'] : ['Present', 'Absent'],
          key: 'Requirements - Death Certificate',
        ),

        _buildSectionHeader(
          isTagalog ? 'DETALYE NG PAGPAPATALA' : 'REGISTRATION DETAILS',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan ng Nagpalista' : 'Registered by',
          key: 'Registration - Registered By',
        ),
        _buildTextField(
          isTagalog ? 'Kaugnayan sa Namatay' : 'Relation to Deceased',
          key: 'Registration - Relation to Deceased',
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Numero ng Telepono' : 'Contact Number',
          key: 'Registration - Contact Number',
        ),
        _buildDateField(
          isTagalog ? 'Petsa ng Pagpapatala' : 'Date Registered',
          key: 'Registration - Date Registered',
        ),
        _buildTextField(
          isTagalog ? 'Donasyon / A.R. Number' : 'Donation / A.R. Number',
          key: 'Registration - Donation AR Number',
        ),

        _buildSubHeader(
          isTagalog ? 'Impormasyon ng Rehistro' : 'Registry Information',
        ),
        _buildTextField(
          isTagalog
              ? 'Numero ng Rehistro ng Kamatayan'
              : 'Death Certificate Registry No.',
          key: 'Registry - Death Certificate No',
        ),
        _buildTextField(
          isTagalog ? 'Numero ng Aklat ng Kamatayan' : 'Death Book No.',
          key: 'Registry - Death Book No',
        ),
        _buildTextField(isTagalog ? 'Pahina' : 'Page', key: 'Registry - Page'),
        _buildTextField(isTagalog ? 'Linya' : 'Line', key: 'Registry - Line'),
      ],
    );
  }

  Widget _buildDetailedWeddingForm(bool isTagalog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(isTagalog ? 'DETALYE NG KASAL' : 'WEDDING DETAILS'),
        _buildDateField(
          isTagalog ? 'Petsa ng Kasal' : 'Date of Wedding',
          key: 'Date of Wedding',
          selectableDayPredicate: _isSelectableSameDayAmPmBookingDate,
        ),
        _buildDropdownField(isTagalog ? 'Araw' : 'Day', const [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ], key: 'Day'),
        _buildTimeField(isTagalog ? 'Oras' : 'Time', key: 'Time'),

        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG LALAKI' : 'GROOM INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan (First Name)' : 'First Name',
          key: 'Groom First Name',
        ),
        _buildTextField(
          isTagalog ? 'Gitnang Pangalan (Middle Name)' : 'Middle Name',
          key: 'Groom Middle Name',
        ),
        _buildTextField(
          isTagalog ? 'Apelyido (Surname)' : 'Surname',
          key: 'Groom Surname',
        ),
        _buildNumberField(
          isTagalog ? 'Edad' : 'Age',
          key: 'Groom Age',
          min: 21,
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Groom Address',
        ),
        _buildTextField(
          isTagalog ? 'Lugar ng Kapanganakan' : 'Place of Birth',
          key: 'Groom Place of Birth',
        ),
        _buildDateField(
          isTagalog ? 'Petsa ng Kapanganakan' : 'Date of Birth',
          isBirthday: true,
          key: 'Groom Date of Birth',
        ),
        _buildTextField(
          isTagalog ? 'Relihiyon' : 'Religion',
          key: 'Groom Religion',
          defaultValue: 'Catholic',
        ),
        _buildDropdownField(isTagalog ? 'Estado' : 'Status', [
          'Single',
          'Annulled',
        ], key: 'Groom Status'),
        _buildTextField(
          isTagalog ? 'Pangalan ng Ama' : 'Father Name',
          key: 'Groom Father Name',
          required: false,
        ),
        _buildTextField(
          isTagalog ? 'Pangalan ng Ina' : 'Mother Name',
          key: 'Groom Mother Name',
          required: false,
        ),

        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG BABAE' : 'BRIDE INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan (First Name)' : 'First Name',
          key: 'Bride First Name',
        ),
        _buildTextField(
          isTagalog ? 'Gitnang Pangalan (Middle Name)' : 'Middle Name',
          key: 'Bride Middle Name',
        ),
        _buildTextField(
          isTagalog ? 'Apelyido (Surname)' : 'Surname',
          key: 'Bride Surname',
        ),
        _buildNumberField(
          isTagalog ? 'Edad' : 'Age',
          key: 'Bride Age',
          min: 21,
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Bride Address',
        ),
        _buildTextField(
          isTagalog ? 'Lugar ng Kapanganakan' : 'Place of Birth',
          key: 'Bride Place of Birth',
        ),
        _buildDateField(
          isTagalog ? 'Petsa ng Kapanganakan' : 'Date of Birth',
          isBirthday: true,
          key: 'Bride Date of Birth',
        ),
        _buildTextField(
          isTagalog ? 'Relihiyon' : 'Religion',
          key: 'Bride Religion',
          defaultValue: 'Catholic',
        ),
        _buildDropdownField(isTagalog ? 'Estado' : 'Status', [
          'Single',
          'Annulled',
        ], key: 'Bride Status'),
        _buildTextField(
          isTagalog ? 'Pangalan ng Ama' : 'Father Name',
          key: 'Bride Father Name',
          required: false,
        ),
        _buildTextField(
          isTagalog ? 'Pangalan ng Ina' : 'Mother Name',
          key: 'Bride Mother Name',
          required: false,
        ),

        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG KOMUNIKASYON' : 'CONTACT INFORMATION',
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Numero ng Telepono' : 'Contact Number',
          key: 'Contact Number',
        ),

        _buildSectionHeader(
          isTagalog ? 'PANGUNAHING NINONG/NINANG' : 'PRINCIPAL SPONSORS',
        ),
        _buildSubHeader(isTagalog ? 'Ninong' : 'Ninong'),
        _buildTextField(isTagalog ? 'Pangalan' : 'Name', key: 'Ninong Name'),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Ninong Address',
        ),
        _buildSubHeader(isTagalog ? 'Ninang' : 'Ninang'),
        _buildTextField(isTagalog ? 'Pangalan' : 'Name', key: 'Ninang Name'),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Ninang Address',
        ),

        _buildSectionHeader(
          isTagalog ? 'KARAGDAGANG NINONG/NINANG' : 'ADDITIONAL GODPARENTS',
        ),
        ..._additionalGodparents.asMap().entries.map((entry) {
          final index = entry.key;
          final godparent = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubSubHeader(
                    isTagalog
                        ? 'Karagdagang Ninong/Ninang ${index + 1}'
                        : 'Additional Godparent ${index + 1}',
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeGodparent(index),
                  ),
                ],
              ),
              _buildGodparentField(
                isTagalog ? 'Pangalan' : 'Name',
                godparent['Name']!,
              ),
              _buildGodparentField(
                isTagalog ? 'Tirahan' : 'Address',
                godparent['Address']!,
              ),
            ],
          );
        }),

        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            onPressed: _addGodparent,
            icon: const Icon(Icons.add),
            label: Text(
              isTagalog ? 'Magdagdag ng Ninong/Ninang' : 'Add Godparent',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedConfirmationForm(bool isTagalog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isTagalog ? 'DETALYE NG KUMPIL' : 'CONFIRMATION DETAILS',
        ),
        _buildDateField(
          isTagalog ? 'Petsa ng Kumpil' : 'Date of Confirmation',
          key: 'Date of Confirmation (Petsa ng Kumpil)',
          selectableDayPredicate: _isSelectableSameDayAmPmBookingDate,
        ),
        _buildTextField(
          isTagalog ? 'Araw' : 'Day',
          key: 'Day (Araw)',
          readOnly: true,
        ),
        _buildTimeField(isTagalog ? 'Oras' : 'Time', key: 'Time (Oras)'),

        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG KALAGAYAN' : 'PERSONAL INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan ng Kukumpilan' : 'Full Name',
          key: 'Full Name (Pangalan ng Kukumpilan)',
        ),
        _buildNumberField(isTagalog ? 'Edad' : 'Age', key: 'Age (Edad)'),
        _buildDropdownField(isTagalog ? 'Kasarian' : 'Gender', const [
          'Male',
          'Female',
        ], key: 'Gender (Kasarian)'),
        _buildDateField(
          isTagalog ? 'Petsa ng Kapanganakan' : 'Date of Birth',
          isBirthday: true,
          key: 'Date of Birth (Petsa ng Kapanganakan)',
        ),
        _buildTextField(
          isTagalog ? 'Lugar ng Kapanganakan' : 'Place of Birth',
          key: 'Place of Birth (Lugar ng Kapanganakan)',
        ),

        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG BINYAG' : 'BAPTISMAL INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Saan Nabinyagan' : 'Place of Baptism',
          key: 'Place of Baptism (Saan Nabinyagan)',
        ),
        _buildDateField(
          isTagalog ? 'Kailan Nabinyagan' : 'Date of Baptism',
          isBirthday: true,
          key: 'Date of Baptism (Kailan Nabinyagan)',
        ),
        _buildTextField(
          isTagalog
              ? 'Parokyang Kinabibilangan (Pangalan at Address)'
              : 'Parish Affiliation (Name of Parish and Address)',
          key: 'Parish Affiliation (Parokyang Kinabibilangan)',
        ),

        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG MGA MAGULANG' : 'PARENTS INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Ama' : 'Father\'s Name',
          key: "Father's Name (Ama)",
          required: false,
        ),
        _buildTextField(
          isTagalog
              ? 'Ina (Apelyido noong dalaga pa)'
              : 'Mother\'s Name (Maiden Name)',
          key: "Mother's Name (Ina - Apelyido noong dalaga pa)",
          required: false,
        ),

        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG KOMUNIKASYON' : 'CONTACT INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Kasalukuyang Tirahan' : 'Current Address',
          key: 'Current Address (Kasalukuyang Tirahan)',
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Numero ng Telepono' : 'Contact Number',
          key: 'Contact Number',
        ),

        _buildSectionHeader(
          isTagalog ? 'MGA NINONG AT NINANG' : 'SPONSORS (Godparents)',
        ),
        _buildSubHeader(isTagalog ? 'Ninong' : 'Ninong'),
        _buildTextField(
          isTagalog ? 'Pangalan' : 'Name',
          key: 'Ninong Name (Pangalan)',
        ),
        _buildNumberField(
          isTagalog ? 'Edad' : 'Age',
          key: 'Ninong Age (Edad)',
          min: 18,
        ),
        _buildDropdownField(
          isTagalog ? 'Relihiyon' : 'Religion',
          [
            'Catholic',
            'Christian',
            'Iglesia ni Cristo',
            'Islam',
            'Prefer not to say',
          ],
          key: 'Ninong Religion',
          defaultValue: 'Prefer not to say',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Ninong Address',
        ),

        _buildSubHeader(isTagalog ? 'Ninang' : 'Ninang'),
        _buildTextField(
          isTagalog ? 'Pangalan' : 'Name',
          key: 'Ninang Name (Pangalan)',
        ),
        _buildNumberField(
          isTagalog ? 'Edad' : 'Age',
          key: 'Ninang Age (Edad)',
          min: 18,
        ),
        _buildDropdownField(
          isTagalog ? 'Relihiyon' : 'Religion',
          [
            'Catholic',
            'Christian',
            'Iglesia ni Cristo',
            'Islam',
            'Prefer not to say',
          ],
          key: 'Ninang Religion',
          defaultValue: 'Prefer not to say',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Ninang Address',
        ),

        _buildSectionHeader(
          isTagalog ? 'KARAGDAGANG NINONG/NINANG' : 'ADDITIONAL GODPARENTS',
        ),
        ..._additionalGodparents.asMap().entries.map((entry) {
          final index = entry.key;
          final godparent = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSubSubHeader(
                    isTagalog
                        ? 'Karagdagang Ninong/Ninang ${index + 1}'
                        : 'Additional Godparent ${index + 1}',
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeGodparent(index),
                  ),
                ],
              ),
              _buildGodparentField(
                isTagalog ? 'Pangalan' : 'Name',
                godparent['Name']!,
              ),
              _buildGodparentAgeField(
                isTagalog ? 'Edad' : 'Age',
                godparent['Age']!,
                minAge: 18,
              ),
              _buildDropdownWithController(
                isTagalog ? 'Relihiyon' : 'Religion',
                godparent['Religion']!,
                [
                  'Catholic',
                  'Christian',
                  'Iglesia ni Cristo',
                  'Islam',
                  'Prefer not to say',
                ],
                defaultValue: 'Prefer not to say',
              ),
              _buildGodparentField(
                isTagalog ? 'Tirahan' : 'Address',
                godparent['Address']!,
              ),
            ],
          );
        }),

        const SizedBox(height: 12),
        Center(
          child: ElevatedButton.icon(
            onPressed: _addGodparent,
            icon: const Icon(Icons.add),
            label: Text(
              isTagalog ? 'Magdagdag ng Ninong/Ninang' : 'Add Godparent',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedHouseBlessingForm(bool isTagalog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG NAGREREQUEST' : 'REQUESTOR INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan' : 'Full Name',
          key: 'Full Name (Pangalan)',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Address (Tirahan)',
        ),

        _buildSectionHeader(isTagalog ? 'ORAS NG BASBAS' : 'BLESSING SCHEDULE'),
        _buildDateField(
          isTagalog ? 'Petsa ng Blessing' : 'Date of Blessing',
          key: 'Date of Blessing',
          selectableDayPredicate: _isSelectableSameDayAmPmBookingDate,
        ),
        _buildTimeField(
          isTagalog ? 'Oras ng Blessing' : 'Time of Blessing',
          key: 'Time of Blessing',
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Cell/Tel. No.' : 'Phone Number',
          key: 'Phone Number (Cell/Tel. No.)',
        ),
      ],
    );
  }

  Widget _buildDetailedAnointingForm(bool isTagalog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG PASYENTE' : 'PATIENT INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Pangalan' : 'Full Name',
          key: 'Full Name (Pangalan)',
        ),
        _buildNumberField(isTagalog ? 'Edad' : 'Age', key: 'Age (Edad)'),
        _buildTextField(
          isTagalog ? 'Sakit' : 'Illness/Condition',
          key: 'Illness/Condition (Sakit)',
        ),
        _buildTextField(
          isTagalog ? 'Tirahan' : 'Address',
          key: 'Address (Tirahan)',
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Cell/Tel. No.' : 'Phone Number',
          key: 'Phone Number (Cell/Tel. No.)',
        ),

        _buildSectionHeader(isTagalog ? 'ORAS NG HAPAG' : 'APPOINTMENT'),
        _buildDateField(
          isTagalog ? 'Petsa' : 'Date',
          key: 'Appointment Date',
          selectableDayPredicate: _isSelectableSameDayAmPmBookingDate,
        ),
        _buildTimeField(isTagalog ? 'Oras' : 'Time', key: 'Appointment Time'),
      ],
    );
  }

  Widget _buildDetailedMassIntentionForm(bool isTagalog) {
    final allowedMassTimes = _massIntentionAllowedTimesForSelectedDate();
    final hasSelectedMassDate =
        (_controllers['Date of Mass (Petsa ng Misa)']?.text.trim() ?? '')
            .isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          isTagalog ? 'IMPORMASYON NG NAGREREQUEST' : 'REQUESTOR INFORMATION',
        ),
        _buildTextField(
          isTagalog ? 'Buong Pangalan ng Nag-aalok' : 'Full Name of Requestor',
          key: 'Full Name of Requestor (Buong Pangalan ng Nag-aalok)',
        ),
        _buildPhilippinePhoneField(
          isTagalog ? 'Numero ng Telepono' : 'Contact Number',
          key: 'Contact Number (Numero ng Telepono)',
        ),

        _buildSectionHeader(
          isTagalog ? 'DETALYE NG MISANG INAALOK' : 'MASS INTENTION DETAILS',
        ),
        _buildTextField(
          isTagalog
              ? 'Kapistahan o Pangalan ng Taong Iaalay'
              : 'Feast or Name of Intended Person',
          key:
              'Feast or Name of Intended Person (Kapistahan o Pangalan ng Taong Iaalay)',
        ),

        _buildSectionHeader(isTagalog ? 'ORAS NG MISA' : 'MASS SCHEDULE'),
        _buildCurrentMassScheduleList(isTagalog),
        _buildDateField(
          isTagalog ? 'Petsa ng Misa' : 'Date of Mass',
          key: 'Date of Mass (Petsa ng Misa)',
          selectableDayPredicate: (d) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final maxDate = now.add(const Duration(days: 365));
            final day = DateTime(d.year, d.month, d.day);
            // Mass intentions are exempt from the 2-day block and can be booked on Mondays when a Mass is scheduled.
            return (day.isAtSameMomentAs(today) || day.isAfter(today)) &&
                day.isBefore(maxDate);
          },
        ),
        _buildTimeField(
          isTagalog ? 'Oras ng Misa' : 'Time of Mass',
          key: 'Time of Mass (Oras ng Misa)',
          allowedTimes: allowedMassTimes,
          disabled:
              !hasSelectedMassDate ||
              _massScheduleLoading ||
              allowedMassTimes.isEmpty,
        ),
        if (hasSelectedMassDate &&
            !_massScheduleLoading &&
            allowedMassTimes.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, bottom: 10.0),
            child: Text(
              isTagalog
                  ? 'Walang available na oras para sa napiling petsa. Kung ngayong araw ito, maaaring lumipas na ang lahat ng oras ng Misa.'
                  : 'No Mass times are available for the selected date. If this is today, all Mass times may have already passed.',
              style: const TextStyle(
                color: ParishColors.textRed500,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}
