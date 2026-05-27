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
    }
  }

  String fullDescription(bool isTagalog) {
    switch (this) {
      case SacramentType.baptism:
        return isTagalog
            ? 'Ang binyag ay ang unang sakramento ng pagiging Kristiyano. Ito ang nagbibigay ng bagong buhay kay Kristo, nag-aalis ng orihinal na kasalanan, at tinatanggap ang binyagan bilang kasapi ng Simbahan.'
            : 'Baptism is the first sacrament of Christian initiation. It gives new life in Christ, frees the person from original sin, and welcomes them as a member of the Church.';
      case SacramentType.confirmation:
        return isTagalog
            ? 'Ang Kumpil ay nagbibigay ng espesyal na pagbubuhos ng Espiritu Santo na mas lalong nagpapatatag at nagpapatibay sa ating binyag upang maging mga saksi ni Kristo.'
            : 'Confirmation brings a special outpouring of the Holy Spirit that deepens and strengthens baptismal grace, empowering us to become true witnesses of Christ.';
      case SacramentType.wedding:
        return isTagalog
            ? 'Ang Kasal ay isang banal na kasunduan sa pagitan ng lalaki at babae, na tinataguyod ng Diyos bilang isang panghabambuhay na pagsasama ng pagmamahalan at katapatan.'
            : 'Holy Matrimony is a sacred covenant between a man and a woman, established by God as a lifelong partnership of love and fidelity.';
      case SacramentType.funeral:
        return isTagalog
            ? 'Ang Misa para sa Yumao ay isang panalangin ng Simbahan para sa kaluluwa ng namayapa, na humihingi sa awa ng Diyos upang siya ay makapasok sa buhay na walang hanggan.'
            : 'The Funeral Mass is a prayer of the Church offering the soul of the departed to God, asking for His mercy so they may enter eternal life.';
      case SacramentType.houseBlessing:
        return isTagalog
            ? 'Ang pagbabasbas ng bahay ay isang panalangin upang hilingin ang gabay at proteksyon ng Diyos para sa tahanan at sa lahat ng naninirahan dito.'
            : 'House blessing is a prayer asking for God\'s light, guidance, and protection for a home and all who dwell within it.';
      case SacramentType.anointing:
        return isTagalog
            ? 'Ang Pagpapahid sa May Sakit ay nagbibigay ng biyaya ng Espiritu Santo na nagdudulot ng lakas, kapayapaan, at tapang sa mga nakakaranas ng matinding karamdaman.'
            : 'The Anointing of the Sick confers a special grace providing strength, peace, and courage to endure the difficulties accompanying serious illness or old age.';
      case SacramentType.massIntention:
        return isTagalog
            ? 'Ang pag-aalay ng intensyon sa Misa ay ang paglalaan ng mga panalangin ng Simbahan para sa mga partikular na pangangailangan, pasasalamat, o para sa mga kaluluwa ng mga namayapa.'
            : 'Offering a Mass intention is a way to apply the graces of the Eucharistic sacrifice for specific needs, thanksgiving, or the souls of the faithfully departed.';
      case SacramentType.firstCommunion:
        return isTagalog
            ? 'Ang Unang Komunyon ay ang unang pagtanggap ng Banal na Eukaristiya. Isang espesyal na pagdiriwang para sa mga mag-aaral na naghahanda para sa kanilang unang pagtanggap ng katawan at dugo ni Kristo.'
            : 'First Communion is the first reception of the Holy Eucharist. A special celebration for students preparing for their first reception of the Body and Blood of Christ.';
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
  final List<String> requirements;
  final Map<String, dynamic> fees;
  final Map<String, dynamic> schedules;
  final String descriptionEnglish;
  final String descriptionTagalog;

  const SacramentFormData({
    required this.title,
    required this.fields,
    required this.requirements,
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

class _SacramentFormScreenState extends State<SacramentFormScreen> {
  _SacramentFormScreenState(); // Add explicit constructor

  final _formKey = GlobalKey<FormState>();
  late SacramentFormData _data;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _dropdownValues;
  final Map<String, bool> _slotTakenCache = {};
  final Map<String, int> _bookingCountCache =
      {}; // Cache booking counts by date
  Future<void>? _bookingCountsLoadFuture;
  bool _bookingCountsLoaded = false;
  bool _isSubmitting = false;
  bool _isSundayBaptismDate = false;
  String? _sundayBaptismTime;
  bool _massScheduleLoading = false;
  bool _hasShownBookingAssistant = false;
  bool _isBookingAssistantOpen = false;
  List<String> _massScheduleTexts = [];
  final List<Map<String, TextEditingController>> _additionalGodparents = [];
  final Map<int, PlatformFile?> _uploadedRequirementImages =
      {}; // Track uploaded images per requirement
  final Map<int, DocumentValidationResult> _validationResults = {};
  final Map<int, bool> _isValidatingDocuments = {};

  // Age eligibility variables
  int? _userAge;
  bool _ageLoading = true;
  String? _ageEligibilityError;
  String _currentParishPriest = '';

  @override
  void initState() {
    super.initState();
    _data = SacramentFormData.forType(widget.sacramentType);
    _controllers = {
      for (final field in _data.fields) field: TextEditingController(),
    };
    _dropdownValues = {};
    _loadBookingFormDefinition();
    _loadUserAge();
    _loadCurrentParishPriest();
    // Pre-load booking counts for calendar (except Mass Intention)
    if (widget.sacramentType != SacramentType.massIntention) {
      _bookingCountsLoadFuture = _preloadBookingCounts();
    }
    if (widget.sacramentType == SacramentType.massIntention) {
      _loadMassIntentionSchedule();
    }
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

      await countCollection('bookings');
      await countCollection('sacrament_requests');

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

      final scheduleTexts = <String>[
        ...?profile?.massSchedule
            .map((item) {
              final label = item.label(widget.isTagalog).trim();
              final time = item.time.trim();
              if (label.isEmpty) return time;
              if (time.isEmpty || label == time) return label;
              return '$label at $time';
            })
            .where((item) => item.trim().isNotEmpty),
        ...await _loadMassScheduleTextsFromFirestore(),
      ];

      setState(() {
        _massScheduleTexts = scheduleTexts.toSet().toList();
        _massScheduleLoading = false;
      });
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
    }.contains(widget.sacramentType);
  }

  bool _isSelectableSameDayAmPmBookingDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final earliestAllowedDate = today.add(const Duration(days: 2));
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
    final earliestAllowedDate = today.add(const Duration(days: 2));

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
          ? 'Hindi available ang napiling petsa. Kailangan ang booking ay hindi bababa sa 2 araw mula ngayon.'
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
    return switch (widget.sacramentType) {
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
    };
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
    };

    for (final key in keys) {
      final value = _controllers[key]?.text.trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    return '';
  }

  List<String> _selectedScheduleTimeKeys() {
    return switch (widget.sacramentType) {
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
    };
  }

  void _clearSelectedScheduleTime() {
    for (final key in _selectedScheduleTimeKeys()) {
      _controllers[key]?.clear();
    }
  }

  Future<void> _loadBookingFormDefinition() async {
    final data = await FirebaseService.instance.getBookingFormDefinition(
      widget.sacramentType.bookingFormKey,
    );
    if (!mounted || data == null) return;

    var nextData = SacramentFormData.fromDatabase(data, _data);
    if (nextData.fields.isEmpty) return;
    if (widget.sacramentType == SacramentType.massIntention) {
      nextData = SacramentFormData(
        title: nextData.title,
        fields: nextData.fields
            .where((field) => !_isDonationArNumberField(field))
            .toList(growable: false),
        requirements: nextData.requirements,
        fees: nextData.fees,
        schedules: nextData.schedules,
        descriptionEnglish: nextData.descriptionEnglish,
        descriptionTagalog: nextData.descriptionTagalog,
      );
    }

    setState(() {
      _data = nextData;
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
          });

          _showModalNotificationGlobal(
            context,
            widget.isTagalog
                ? 'Matagumpay na na-upload!'
                : 'Successfully uploaded!',
            bgColor: ParishColors.greenSuccess,
          );
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
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                widget.isTagalog ? 'Di Validong Dokumento' : 'Invalid Document',
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
                  widget.isTagalog
                      ? 'Hindi namin makilalang mabuti ang dokumentong ito.'
                      : 'We could not recognize this document.',
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
                  widget.isTagalog
                      ? 'Subukan muli gamit ang malinaw at kumpletong dokumento.'
                      : 'Please try again with a clear and complete document.',
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
        print(
          'DEBUG: Skipping requirement ${_data.requirements[i]} - missing file or validation',
        );
      }
    }

    print('DEBUG: Finished saving all requirements');
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
      // Parent validation for wedding form
      if (widget.sacramentType == SacramentType.wedding) {
        final groomFather =
            _controllers['Groom Father Name']?.text.trim() ?? '';
        final groomMother =
            _controllers['Groom Mother Name']?.text.trim() ?? '';
        final brideFather =
            _controllers['Bride Father Name']?.text.trim() ?? '';
        final brideMother =
            _controllers['Bride Mother Name']?.text.trim() ?? '';

        if ((groomFather.isEmpty && groomMother.isEmpty) ||
            (brideFather.isEmpty && brideMother.isEmpty)) {
          _showModalNotificationGlobal(
            context,
            widget.isTagalog
                ? 'Kailangan ang kahit isang magulang (ama o ina) para sa bawat magkasintahan.'
                : 'At least one parent (father or mother) is required for both the groom and bride.',
            bgColor: Colors.red,
          );
          return;
        }
      }

      final selectedDate = _selectedScheduleDate();
      final selectedTime = _selectedScheduleTime();

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
        final selectedDateTime = DateTime.tryParse(selectedDate);
        final bool isSundayBaptism =
            widget.sacramentType == SacramentType.baptism &&
            selectedDateTime != null &&
            selectedDateTime.weekday == DateTime.sunday;

        if (await _isBlockedByMassSchedule(
          date: selectedDate,
          time: selectedTime,
        )) {
          _showMassScheduleBlockedMessage();
          return;
        }

        if (!isSundayBaptism &&
            widget.sacramentType != SacramentType.massIntention) {
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

          final parsed = DateTime.tryParse(date);
          final isSunday = parsed != null && parsed.weekday == DateTime.sunday;
          final normalized = time.replaceAll(' ', '').toLowerCase();
          final isEight = normalized.contains('8:00');
          if (isEight && !isSunday) {
            _showModalNotificationGlobal(
              context,
              widget.isTagalog
                  ? 'Ang 8:00 AM ay para lamang sa Linggo.'
                  : '8:00 AM is available on Sundays only.',
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

      final additionalGodparents = _additionalGodparents
          .map(
            (godparent) => godparent.map(
              (field, controller) => MapEntry(field, controller.text.trim()),
            ),
          )
          .toList();

      try {
        await FirebaseService.instance.submitBooking(
          sacramentType: widget.sacramentType.label(widget.isTagalog),
          details: {
            'fields': fieldValues,
            'additionalGodparents': additionalGodparents,
          },
        );

        _showModalNotificationGlobal(
          context,
          widget.isTagalog
              ? '${_data.title} naipadala! Pang hintayin ang aprubasyon ng admin bago magbayad.'
              : '${_data.title} submitted! Please wait for admin approval before proceeding to payment.',
          bgColor: ParishColors.greenSuccess,
        );

        // Original booking success alert - show immediately after booking is created
        _showModalNotificationGlobal(
          context,
          widget.isTagalog
              ? '${_data.title} naipadala!'
              : '${_data.title} submitted!',
          bgColor: ParishColors.greenSuccess,
        );

        // Save all uploaded requirements after successful booking creation
        await _saveAllRequirements();

        // Additional alert for requirements being saved
        _showModalNotificationGlobal(
          context,
          widget.isTagalog
              ? 'Ang mga requirements ay nai-save na.'
              : 'Requirements have been saved.',
          bgColor: ParishColors.greenSuccess,
        );

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

    // Regular requirement item with upload functionality
    final isUploaded = _uploadedRequirementImages[index] != null;
    final file = _uploadedRequirementImages[index];
    final isValidating = _isValidatingDocuments[index] ?? false;
    final validationResult = _validationResults[index];
    final fileName = isUploaded
        ? file!.name
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
              color: isUploaded ? Colors.blue.shade50 : Colors.grey.shade50,
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
                ElevatedButton.icon(
                  onPressed: isValidating
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
  }) {
    final fieldKey = key ?? label;
    _controllers.putIfAbsent(fieldKey, () => TextEditingController());

    if (allowedTimes != null && allowedTimes.isNotEmpty) {
      final allowedValues = allowedTimes.map(_formatTimeOfDay).toList();
      final currentValue = _controllers[fieldKey]!.text;
      final selectedValue = allowedValues.contains(currentValue)
          ? currentValue
          : allowedValues.first;
      if (_controllers[fieldKey]!.text != selectedValue) {
        _controllers[fieldKey]!.text = selectedValue;
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          initialValue: selectedValue,
          items: allowedValues.map((option) {
            return DropdownMenuItem<String>(value: option, child: Text(option));
          }).toList(),
          onChanged: disabled
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
    if (widget.sacramentType == SacramentType.massIntention) {
      final times = <TimeOfDay>[];
      for (final scheduleText in _massScheduleTexts) {
        if (!_scheduleTextAppliesToDate(scheduleText, date)) continue;
        for (final time in _extractMassTimesFromText(scheduleText)) {
          if (_isPastMassIntentionTime(date, time)) continue;
          final exists = times.any(
            (item) => item.hour == time.hour && item.minute == time.minute,
          );
          if (!exists) times.add(time);
        }
      }
      times.sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
      return times.map(_formatTimeOfDay).toList();
    }

    if (widget.sacramentType == SacramentType.baptism &&
        date.weekday == DateTime.sunday) {
      final sundayTime =
          await _loadSundayBaptismTime(date) ??
          _formatTimeOfDay(const TimeOfDay(hour: 9, minute: 0));
      return [sundayTime];
    }

    return const ['8:00 AM', '10:00 AM', '2:00 PM', '4:00 PM'];
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
    final bookedDates = <String>{};
    final monthPrefix = '$year-${month.toString().padLeft(2, '0')}-';

    for (final collection in ['bookings', 'sacrament_requests']) {
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
          return null;
        } else {
          debugPrint(
            'AI Booking Assistant: could not read $collection for recommendations: $e',
          );
        }
      }
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
    final firstAllowedDay = enforceLeadTime
        ? today.add(const Duration(days: 2))
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

    for (
      var date = searchStart;
      !date.isAfter(searchEnd);
      date = date.add(const Duration(days: 1))
    ) {
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
        var isMassBlocked = false;
        try {
          isMassBlocked = await _isBlockedByMassSchedule(
            date: dateValue,
            time: time,
          );
        } catch (e) {
          debugPrint(
            'AI Booking Assistant: Mass schedule check failed for $dateValue $time: $e',
          );
        }
        if (isMassBlocked) {
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

      for (
        var date = searchStart;
        !date.isAfter(searchEnd);
        date = date.add(const Duration(days: 1))
      ) {
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
          var isMassBlocked = false;
          try {
            isMassBlocked = await _isBlockedByMassSchedule(
              date: dateValue,
              time: time,
            );
          } catch (e) {
            debugPrint(
              'AI Booking Assistant: Mass schedule check failed for $dateValue $time: $e',
            );
          }
          if (isMassBlocked) continue;

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

    final sundayBaptism =
        widget.sacramentType == SacramentType.baptism &&
        slot.date.weekday == DateTime.sunday;
    setState(() {
      _controllers[dateKeys.first]?.text = slot.dateValue;
      _controllers[timeKeys.first]?.text = slot.timeValue;
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
        _controllers['Time of Mass (Oras ng Misa)']?.text = slot.timeValue;
      }
    });
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
      r'^(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?\$',
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
      DateTime.monday: ['monday', 'mon'],
      DateTime.tuesday: ['tuesday', 'tue'],
      DateTime.wednesday: ['wednesday', 'wed'],
      DateTime.thursday: ['thursday', 'thu'],
      DateTime.friday: ['friday', 'fri'],
      DateTime.saturday: ['saturday', 'sat'],
      DateTime.sunday: ['sunday', 'sun'],
    };

    final mentionedDays = names.entries
        .where((entry) => entry.value.any((name) => text.contains(name)))
        .map((entry) => entry.key)
        .toSet();

    if (mentionedDays.isEmpty) return true;
    return mentionedDays.contains(weekday);
  }

  List<TimeOfDay> _massIntentionAllowedTimesForSelectedDate() {
    final dateValue =
        _controllers['Date of Mass (Petsa ng Misa)']?.text.trim() ?? '';
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
      final snapshot = await FirebaseFirestore.instance
          .collection('mass_schedules')
          .where('date', isEqualTo: dateStr)
          .get();

      final massTimes = <TimeOfDay>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawTime = (data['time'] ?? data['timeString'] ?? '').toString();
        final time = _parseTimeOfDay(rawTime);
        if (time != null) {
          massTimes.add(time);
        }
      }

      if (massTimes.isEmpty) {
        return null;
      }

      massTimes.sort((a, b) {
        final aMinutes = a.hour * 60 + a.minute;
        final bMinutes = b.hour * 60 + b.minute;
        return aMinutes.compareTo(bMinutes);
      });

      final firstMass = massTimes.first;
      final nextHour = TimeOfDay(
        hour: (firstMass.hour + 1) % 24,
        minute: firstMass.minute,
      );
      return _formatTimeOfDay(nextHour);
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkSchedulingConflictOnSelection() async {
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
    }

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
            if (fieldKey == 'Registration - Date of Baptism') {
              final bool sunday = picked.weekday == DateTime.sunday;
              String? sundayTime;
              if (sunday) {
                sundayTime =
                    await _loadSundayBaptismTime(picked) ??
                    _formatTimeOfDay(const TimeOfDay(hour: 9, minute: 0));
              }
              setState(() {
                _controllers[fieldKey]!.text = selectedDate;
                _isSundayBaptismDate = sunday;
                _sundayBaptismTime = sundayTime;
                // Safely set the time controller without forcing a null
                _controllers['Registration - Time of Baptism']?.text = (sunday
                    ? (sundayTime ?? '')
                    : '');
              });
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

    // Show loading indicator while checking age eligibility
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
                      // Hide requirements title for First Communion (no requirements)
                      if (widget.sacramentType !=
                          SacramentType.firstCommunion) ...[
                        Text(
                          isTagalog
                              ? 'Mga Kinakailangang Dokumento / Requirements'
                              : 'Required Documents / Requirements',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
                      if (widget.sacramentType == SacramentType.baptism)
                        _buildDetailedBaptismForm(isTagalog)
                      else if (widget.sacramentType == SacramentType.funeral)
                        _buildDetailedFuneralForm(isTagalog)
                      else if (widget.sacramentType == SacramentType.wedding)
                        _buildDetailedWeddingForm(isTagalog)
                      else if (widget.sacramentType ==
                          SacramentType.confirmation)
                        _buildDetailedConfirmationForm(isTagalog)
                      else if (widget.sacramentType ==
                          SacramentType.houseBlessing)
                        _buildDetailedHouseBlessingForm(isTagalog)
                      else if (widget.sacramentType == SacramentType.anointing)
                        _buildDetailedAnointingForm(isTagalog)
                      else if (widget.sacramentType ==
                          SacramentType.massIntention)
                        _buildDetailedMassIntentionForm(isTagalog)
                      else if (widget.sacramentType ==
                          SacramentType.firstCommunion)
                        _buildDetailedFirstCommunionForm(isTagalog)
                      else
                        Column(
                          children: _data.fields.map((field) {
                            // Check if this is a section header
                            if (field.startsWith('[SECTION]')) {
                              final sectionTitle = field.replaceFirst(
                                '[SECTION] ',
                                '',
                              );
                              return _buildSectionHeader(sectionTitle);
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                              ),
                              child: TextFormField(
                                controller: _controllers[field],
                                decoration: InputDecoration(
                                  labelText: field,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return isTagalog
                                        ? 'Pakitiyak na punuin ang $field'
                                        : 'Please fill in $field';
                                  }
                                  return null;
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
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
