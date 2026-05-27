import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/responsive.dart';
import '../../../core/widgets/responsive_modal.dart';
import '../../../core/services/firebase_service.dart';

class _BookingFormFeeCache {
  _BookingFormFeeCache._();
  static final _BookingFormFeeCache instance = _BookingFormFeeCache._();

  Future<void>? _loadFuture;
  final Map<String, Map<String, dynamic>> _feesByForm = {
    'baptism': {
      'sunday': 300,
      'weekday': 1650,
    },
    'wedding': {
      'base': 6000,
    },
  };

  Future<void> load() {
    return _loadFuture ??= _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('booking_forms')
          .where('active', isEqualTo: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fees = data['fees'];
        if (fees is Map) {
          _feesByForm[doc.id] = Map<String, dynamic>.from(fees);
        }
      }
    } catch (e) {
      debugPrint('Failed to load booking form fees: $e');
    }
  }

  int baptismAmount({required bool isSunday}) {
    final fees = _feesByForm['baptism'] ?? const <String, dynamic>{};
    return _asInt(fees[isSunday ? 'sunday' : 'weekday'], isSunday ? 300 : 1650);
  }

  int weddingAmount() {
    final fees = _feesByForm['wedding'] ?? const <String, dynamic>{};
    return _asInt(fees['base'] ?? fees['regular'], 6000);
  }

  int _asInt(dynamic value, int fallback) {
    if (value is num) return value.round();
    if (value is String) {
      final parsed = num.tryParse(value.replaceAll(RegExp(r'[^\d.]'), ''));
      if (parsed != null) return parsed.round();
    }
    return fallback;
  }
}

class BookingsScreen extends StatelessWidget {
  final bool isTagalog;
  final VoidCallback? onStartBooking;

  const BookingsScreen({super.key, this.isTagalog = true, this.onStartBooking});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _BookingFormFeeCache.instance.load(),
      builder: (context, _) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseService.instance.userBookingsStream(),
          builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading bookings: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final bookings = docs.toList()
          ..sort((a, b) {
            final aTime =
                (a.data()['submittedAt'] as Timestamp?)?.toDate() ??
                DateTime(1900);
            final bTime =
                (b.data()['submittedAt'] as Timestamp?)?.toDate() ??
                DateTime(1900);
            return bTime.compareTo(aTime); // descending
          });

        if (bookings.isEmpty) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTagalog ? 'Aking mga Booking' : 'My Bookings',
                    style: TextStyle(
                      fontSize: 24,
                      color: ParishColors.textBlue900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: ParishColors.bgBlue50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ParishColors.borderBlue100),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 48,
                          color: ParishColors.primaryBlue.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isTagalog ? 'Walang Booking' : 'No Bookings',
                          style: TextStyle(
                            fontSize: 18,
                            color: ParishColors.textBlue900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isTagalog
                              ? 'Magsimula ng pag-book ng isang sakramento ngayon'
                              : 'Start booking a sacrament now',
                          style: TextStyle(
                            fontSize: 14,
                            color: ParishColors.textGray600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: onStartBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isTagalog
                                ? 'Mag-Book ng Sakramento'
                                : 'Book a Sacrament',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTagalog ? 'Aking mga Booking' : 'My Bookings',
                  style: TextStyle(
                    fontSize: 24,
                    color: ParishColors.textBlue900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bookings.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final booking = bookings[index].data();
                    final timestamp = booking['submittedAt'];
                    final submittedAt = timestamp is Timestamp
                        ? timestamp.toDate()
                        : null;
                    final submittedText = submittedAt != null
                        ? '${submittedAt.month}/${submittedAt.day}/${submittedAt.year}'
                        : '-';
                    final details =
                        booking['details'] as Map<String, dynamic>? ?? {};
                    final fields =
                        details['fields'] as Map<String, dynamic>? ?? {};
                    final status = _resolveBookingEffectiveStatus(booking);
                    final statusLabel = _formatBookingStatus(isTagalog, status);
                    final statusColor = _bookingStatusColor(status);
                    final statusBackground = _bookingStatusBackgroundColor(
                      status,
                    );
                    final summarySubtitle = _bookingSummarySubtitle(
                      fields,
                      submittedText,
                      isTagalog,
                    );
                    final submittedLabel = isTagalog
                        ? 'Isinumite: $submittedText'
                        : 'Submitted: $submittedText';

                    return GestureDetector(
                      onTap: () {
                        _showBookingDetails(
                          context,
                          booking,
                          bookings[index].id,
                          isTagalog,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: ParishColors.borderBlue100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  booking['sacramentType'] as String? ??
                                      (isTagalog
                                          ? 'Sakramentong Booking'
                                          : 'Sacrament Booking'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: ParishColors.textBlue900,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBackground,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 2,
                              color: ParishColors.primaryBlue.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (summarySubtitle.isNotEmpty) ...[
                              Text(
                                summarySubtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ParishColors.textGray700,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              submittedLabel,
                              style: TextStyle(
                                fontSize: 13,
                                color: ParishColors.textGray600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isTagalog
                                  ? 'Tingnan ang buong booking details'
                                  : 'View full booking details',
                              style: TextStyle(
                                fontSize: 14,
                                color: ParishColors.primaryBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  String _formatBookingStatus(bool isTagalog, String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'approved' || normalized == 'accepted') {
      return isTagalog ? 'APRUBADO' : 'APPROVED';
    }
    if (normalized == 'rejected' || normalized == 'declined') {
      return isTagalog ? 'TINANGGI' : 'REJECTED';
    }
    if (normalized == 'cancelled' || normalized == 'canceled') {
      return isTagalog ? 'KINANSELA' : 'CANCELLED';
    }
    if (normalized == 'paid') {
      return isTagalog ? 'BINAYAD' : 'PAID';
    }
    if (normalized == 'pending') {
      return isTagalog ? 'PENDING' : 'PENDING';
    }
    return status.toUpperCase();
  }

  String _resolveBookingEffectiveStatus(Map<String, dynamic> booking) {
    final status = (booking['status'] as String?)?.toLowerCase() ?? '';

    // Priority 1: Check if the booking status field is already 'paid'
    if (status == 'paid') {
      return 'paid';
    }

    // Priority 2: Inspect xendit metadata if present
    String xenditStatus = '';
    bool xenditPaidAtPresent = false;
    bool xenditSettledAtPresent = false;
    final xendit = booking['xendit'];
    if (xendit is Map<String, dynamic>) {
      xenditStatus = (xendit['status'] as String?)?.toLowerCase() ?? '';
      xenditPaidAtPresent = xendit['paidAt'] != null;
      xenditSettledAtPresent = xendit['settledAt'] != null;
    }

    // Check xendit status - if paid or settled, the booking is paid
    if (xenditStatus == 'paid' ||
        xenditStatus == 'settled' ||
        xenditPaidAtPresent ||
        xenditSettledAtPresent) {
      return 'paid';
    }

    // Priority 3: Check legacy or alternative payment records
    bool hasPaidPaymentRecord = false;
    final payments = booking['payments'];
    if (payments is List) {
      for (final p in payments) {
        if (p is Map && (p['status'] as String?)?.toLowerCase() == 'paid') {
          hasPaidPaymentRecord = true;
          break;
        }
      }
    } else if (payments is Map) {
      if ((payments['status'] as String?)?.toLowerCase() == 'paid') {
        hasPaidPaymentRecord = true;
      }
    }

    if (hasPaidPaymentRecord) {
      return 'paid';
    }

    // If none of the paid indicators are present, return the raw status
    return status;
  }

  Color _bookingStatusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'approved' || normalized == 'accepted') {
      return Colors.green.shade700;
    }
    if (normalized == 'rejected' || normalized == 'declined') {
      return Colors.red.shade700;
    }
    if (normalized == 'paid') {
      return Colors.green.shade700;
    }
    if (normalized == 'cancelled' || normalized == 'canceled') {
      return Colors.orange.shade800;
    }
    return ParishColors.primaryBlue;
  }

  Color _bookingStatusBackgroundColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'approved' || normalized == 'accepted') {
      return Colors.green.withValues(alpha: 0.12);
    }
    if (normalized == 'rejected' || normalized == 'declined') {
      return Colors.red.withValues(alpha: 0.12);
    }
    if (normalized == 'paid') {
      return Colors.green.withValues(alpha: 0.12);
    }
    if (normalized == 'cancelled' || normalized == 'canceled') {
      return Colors.orange.withValues(alpha: 0.12);
    }
    return ParishColors.primaryBlue.withValues(alpha: 0.12);
  }

  String _bookingSummarySubtitle(
    Map<String, dynamic> fields,
    String submittedText,
    bool isTagalog,
  ) {
    final date = _findFirstFieldValue(fields, [
      'Date',
      'date',
      'Scheduled Date',
      'scheduledDate',
      'Booking Date',
      'serviceDate',
    ]);
    final time = _findFirstFieldValue(fields, [
      'Time',
      'time',
      'Scheduled Time',
      'scheduledTime',
      'Booking Time',
      'serviceTime',
    ]);

    if (date.isNotEmpty || time.isNotEmpty) {
      final dateLabel = isTagalog ? 'Araw' : 'Date';
      final timeLabel = isTagalog ? 'Oras' : 'Time';
      if (date.isNotEmpty && time.isNotEmpty) {
        return '$dateLabel: $date · $timeLabel: $time';
      }
      if (date.isNotEmpty) {
        return '$dateLabel: $date';
      }
      return '$timeLabel: $time';
    }

    return '';
  }

  String _findFirstFieldValue(Map<String, dynamic> fields, List<String> keys) {
    for (final key in keys) {
      final value = fields[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String _resolveBookingSacramentType(Map<String, dynamic> booking) {
    final candidates = [
      booking['sacramentType'],
      booking['sacrament'],
      booking['type'],
      booking['sacramentTypeKey'],
      booking['typeKey'],
    ];

    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }

    final details = booking['details'] as Map<String, dynamic>?;
    if (details != null) {
      final fields = details['fields'] as Map<String, dynamic>?;
      if (fields != null) {
        final sacramentFromFields = _findFirstFieldValue(fields, [
          'Sacrament Type',
          'sacramentType',
          'sacrament',
          'type',
          'Sacrament',
        ]);
        if (sacramentFromFields.isNotEmpty) {
          return sacramentFromFields;
        }
      }
    }

    return '';
  }

  String _humanizeFieldKey(String key) {
    var text = key.replaceAll(RegExp(r'[_\-]'), ' ');
    text = text.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    );
    final words = text.split(' ');
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  bool _canProceedToPayment(String sacramentType, String status) {
    final normalizedStatus = status.toLowerCase();
    final statusOk = normalizedStatus == 'approved' || normalizedStatus == 'accepted';
    
    // Only allow payment for Wedding and Baptism
    final lowerType = sacramentType.toLowerCase();
    final isPaymentRequired = (lowerType.contains('wedding') || lowerType.contains('kasal')) ||
                            (lowerType.contains('bapt') || lowerType.contains('binyag'));
    
    return statusOk && isPaymentRequired;
  }

  int _computeBookingPaymentAmount(
    String sacramentType,
    bool isSundayBooking,
    Map<String, dynamic> fields,
  ) {
    final isBaptism = _isBaptismBooking(sacramentType, fields);
    if (isBaptism) {
      return _BookingFormFeeCache.instance.baptismAmount(
        isSunday: isSundayBooking,
      );
    }

    final lowerType = sacramentType.toLowerCase();
    if (lowerType.contains('wedding') || lowerType.contains('kasal')) {
      return _BookingFormFeeCache.instance.weddingAmount();
    }
    return 0;
  }

  DateTime? _resolveBookingDate(
    Map<String, dynamic> booking,
    Map<String, dynamic> fields,
  ) {
    final rootDate = booking['date']?.toString().trim() ?? '';
    final rawDate = rootDate.isNotEmpty
        ? rootDate
        : _findFirstFieldValue(fields, [
            'Registration - Date of Baptism',
            'Date',
            'date',
            'Scheduled Date',
            'scheduledDate',
            'Booking Date',
            'serviceDate',
            'Date of Baptism',
            'Petsa ng Binyag',
            'Date of Wedding',
            'Petsa ng Kasal',
          ]);

    return _parseDateString(rawDate);
  }

  bool _isBaptismBooking(String sacramentType, Map<String, dynamic> fields) {
    final lowerType = sacramentType.toLowerCase();
    if (lowerType.contains('bapt') || lowerType.contains('binyag')) {
      return true;
    }

    // Check common field keys that indicate baptism
    if (fields.isNotEmpty) {
      final keysToCheck = [
        'Date of Baptism',
        'Petsa ng Binyag',
        'Baptism Date',
        'baptismDate',
        'baptism_date',
        'Baptism',
        'sacrament',
        'sacramentType',
      ];
      for (final key in keysToCheck) {
        final value = fields[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          final v = value.toString().toLowerCase();
          if (v.contains('bapt') || v.contains('binyag')) return true;
        }
      }
    }

    return false;
  }

  DateTime? _parseDateString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null) return parsed;

    final isoMatch = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(trimmed);
    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1)!);
      final month = int.tryParse(isoMatch.group(2)!);
      final day = int.tryParse(isoMatch.group(3)!);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }

    final dmYMatch = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(trimmed);
    if (dmYMatch != null) {
      final day = int.tryParse(dmYMatch.group(1)!);
      final month = int.tryParse(dmYMatch.group(2)!);
      final year = int.tryParse(dmYMatch.group(3)!);
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }

  Future<bool> _showPaymentSummaryDialog(
    BuildContext context,
    int amount,
    String sacramentType,
    bool isSundayBooking,
    bool isTagalog,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            final formattedAmount = 'PHP ${amount.toStringAsFixed(2)}';
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: ParishColors.primaryBlue,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Text(
                        isTagalog ? 'Kabuuang Bayad' : 'Total Payment',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isTagalog
                                ? 'Ang kabuuang babayaran para sa booking na ito ay:'
                                : 'The total amount to pay for this booking is:',
                          ),
                          const SizedBox(height: 16),
                          Text(
                            formattedAmount,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isSundayBooking
                                ? (isTagalog
                                      ? 'Presyo para sa Linggo: PHP ${_BookingFormFeeCache.instance.baptismAmount(isSunday: true)}'
                                      : 'Sunday price: PHP ${_BookingFormFeeCache.instance.baptismAmount(isSunday: true)}')
                                : (isTagalog
                                      ? 'Presyo para sa Lunes hanggang Sabado: PHP ${_BookingFormFeeCache.instance.baptismAmount(isSunday: false)}'
                                      : 'Monday to Saturday price: PHP ${_BookingFormFeeCache.instance.baptismAmount(isSunday: false)}'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(isTagalog ? 'Kanselahin' : 'Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(isTagalog ? 'Magpatuloy' : 'Proceed'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;
  }

  Future<void> _handleProceedToPayment(
    BuildContext context,
    Map<String, dynamic> booking,
    String bookingId,
    bool isTagalog,
  ) async {
    // Check approval status first
    final effectiveStatus = _resolveBookingEffectiveStatus(booking);
    final statusLower = effectiveStatus.toLowerCase();

    if (statusLower != 'approved' && statusLower != 'accepted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTagalog
                ? 'Hindi ka maaaring magbayad hanggang sa maapprove ng admin. Kasalukuyang status: ${_formatBookingStatus(isTagalog, effectiveStatus)}'
                : 'You cannot proceed to payment until the admin approves this booking. Current status: ${_formatBookingStatus(isTagalog, effectiveStatus)}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Proceed directly with payment
    await _proceedToPaymentWithAmount(
      context,
      booking,
      bookingId,
      isTagalog,
    );
  }

  Future<void> _proceedToPaymentWithAmount(
    BuildContext context,
    Map<String, dynamic> booking,
    String bookingId,
    bool isTagalog,
  ) async {
    final details = booking['details'] as Map<String, dynamic>? ?? {};
    final fields = details['fields'] as Map<String, dynamic>? ?? {};
    final sacramentType = _resolveBookingSacramentType(booking);
    final messenger = ScaffoldMessenger.of(context);
    final isSundayBooking =
        _resolveBookingDate(booking, fields)?.weekday == DateTime.sunday;

    int amount = _computeBookingPaymentAmount(
      sacramentType,
      isSundayBooking,
      fields,
    );

    final effectiveStatus = _resolveBookingEffectiveStatus(booking);
    if (effectiveStatus == 'paid') {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isTagalog
                ? 'Ang booking na ito ay bayad na. Wala nang karagdagang bayad.'
                : 'This booking is already paid. No additional payment is required.',
          ),
        ),
      );
      return;
    }

    final feeBreakdown = {
      'total': amount,
      'currency': 'PHP',
    };

    final bookingDetails = {
      'fields': fields,
      'additionalGodparents':
          details['additionalGodparents'] ?? <Map<String, dynamic>>[],
    };

    try {
      // Show loading indicator
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      isTagalog
                          ? 'Naghahanda ng bayad...'
                          : 'Preparing payment...',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }

      final xendit = await FirebaseService.instance.createXenditBookingInvoice(
        amount: amount.toDouble(),
        sacramentType: sacramentType.trim(),
        bookingId: bookingId,
        details: bookingDetails,
        feeBreakdown: feeBreakdown,
        userName: FirebaseService.instance.currentUserName,
        userEmail: FirebaseService.instance.currentUserEmail,
      );

      // Close the loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      final alreadyPaid = xendit['alreadyPaid'] == true;
      final checkoutUrl = (xendit['checkoutUrl'] ?? '').toString();
      if (alreadyPaid) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isTagalog
                  ? 'Ang booking ay bayad na. Isang email ang ipinadala na nagko-confirm.'
                  : 'This booking is already paid. A confirmation email has been sent.',
            ),
          ),
        );
        return;
      }

      if (checkoutUrl.isEmpty) {
        throw Exception('Missing checkoutUrl');
      }
      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null) {
        throw Exception('Invalid checkoutUrl');
      }

      // Launch payment URL
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('Unable to open payment page');
      }

      // Show snackbar and then refresh booking status after a delay
      // The webhook typically completes within a few seconds
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isTagalog
                ? 'Binubuksan ang payment page. Kumpletuhin ang iyong bayad. Ang page ay mag-refresh pagkatapos mong magbayad.'
                : 'Opening payment page. Complete your payment there. The page will refresh after payment.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      // Wait for a reasonable time for the webhook to process
      // Then refresh the booking data automatically
      Future.delayed(const Duration(seconds: 3), () {
        if (context.mounted) {
          // The StreamBuilder will automatically refresh as the Firestore document updates
          // This delay gives the webhook time to process the payment
      debugPrint(
        'Booking payment flow complete - waiting for webhook to update status',
      );
        }
      });
    } catch (e) {
      // Close the loading dialog if still open
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isTagalog
                ? 'Hindi maiproseso ang payment. Pakisubukang muli. ${e.toString()}'
                : 'Unable to process payment. Please try again. ${e.toString()}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );

      debugPrint('Payment processing error: $e');
    }
  }

  bool _hasBookingDetailValue(dynamic value) {
    return value?.toString().trim().isNotEmpty ?? false;
  }

  String _bookingDetailValue(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    return value?.toString().trim() ?? '';
  }

  String _fieldGroupForBookingDetails(String key) {
    final lower = key.toLowerCase();

    if (lower.contains('father') ||
        lower.contains('mother') ||
        lower.contains('parent') ||
        lower.contains('guardian') ||
        lower.contains('godparent') ||
        lower.contains('sponsor') ||
        lower.contains('ninong') ||
        lower.contains('ninang') ||
        lower.contains('witness')) {
      return 'family';
    }

    if (lower.contains('date') ||
        lower.contains('time') ||
        lower.contains('schedule') ||
        lower.contains('registration') ||
        lower.contains('appointment') ||
        lower.contains('minister') ||
        lower.contains('priest') ||
        lower.contains('mass') ||
        lower.contains('burial') ||
        lower.contains('blessing')) {
      return 'booking';
    }

    if (lower.contains('name') ||
        lower.contains('child') ||
        lower.contains('deceased') ||
        lower.contains('groom') ||
        lower.contains('bride') ||
        lower.contains('gender') ||
        lower.contains('birth') ||
        lower.contains('age') ||
        lower.contains('contact') ||
        lower.contains('email') ||
        lower.contains('phone') ||
        lower.contains('mobile') ||
        lower.contains('address') ||
        lower.contains('place') ||
        lower.contains('religion') ||
        lower.contains('status')) {
      return 'person';
    }

    return 'other';
  }

  Map<String, List<MapEntry<String, String>>> _groupBookingDetailFields(
    Map<String, dynamic> fields,
    List<dynamic> additionalGodparents,
  ) {
    final grouped = <String, List<MapEntry<String, String>>>{
      'booking': [],
      'person': [],
      'family': [],
      'other': [],
    };

    for (final entry in fields.entries) {
      if (!_hasBookingDetailValue(entry.value)) continue;
      final group = _fieldGroupForBookingDetails(entry.key);
      grouped[group]!.add(
        MapEntry(
          _humanizeFieldKey(entry.key),
          _bookingDetailValue(entry.value),
        ),
      );
    }

    for (var i = 0; i < additionalGodparents.length; i++) {
      final godparent = additionalGodparents[i];
      if (godparent is! Map) continue;

      for (final entry in godparent.entries) {
        if (!_hasBookingDetailValue(entry.value)) continue;
        grouped['family']!.add(
          MapEntry(
            'Godparent ${i + 1} - ${_humanizeFieldKey(entry.key.toString())}',
            _bookingDetailValue(entry.value),
          ),
        );
      }
    }

    return grouped;
  }

  Widget _buildBookingDetailSection(
    String title,
    List<MapEntry<String, String>> items,
    bool isMobile,
  ) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 14),
      decoration: BoxDecoration(
        color: ParishColors.bgBlue50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ParishColors.borderBlue100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: ParishColors.textBlue900,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.key,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ParishColors.textGray600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.value,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.35,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 150,
                          child: Text(
                            item.key,
                            style: const TextStyle(
                              fontSize: 12,
                              color: ParishColors.textGray600,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.value,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingNoteSection(
    String title,
    String value,
    bool isMobile,
  ) {
    return _buildBookingDetailSection(
      title,
      [MapEntry('Note', value)],
      isMobile,
    );
  }

  void _showBookingDetails(
    BuildContext context,
    Map<String, dynamic> booking,
    String bookingId,
    bool isTagalog,
  ) {
    final detailsMap = booking['details'] as Map<String, dynamic>? ?? {};
    final fields = detailsMap['fields'] as Map<String, dynamic>? ?? {};
    final status = _resolveBookingEffectiveStatus(booking);
    final followUpNotes =
        booking['documentFollowUpNotes']?.toString().trim() ?? '';
    final adminNotes = booking['adminNotes']?.toString().trim() ?? '';
    final assignedPriest = booking['assignedPriest']?.toString().trim() ?? '';
    final sacramentType = _resolveBookingSacramentType(booking);
    final parsedDate = _resolveBookingDate(booking, fields);
    final isSundayBooking = parsedDate?.weekday == DateTime.sunday;
    final isBaptism = _isBaptismBooking(sacramentType, fields);
    final amount = _computeBookingPaymentAmount(
      sacramentType,
      isSundayBooking,
      fields,
    );
    final additionalGodparents = detailsMap['additionalGodparents'] is List
        ? detailsMap['additionalGodparents'] as List<dynamic>
        : const <dynamic>[];
    final groupedFields = _groupBookingDetailFields(
      fields,
      additionalGodparents,
    );
    final bookingInfoItems = <MapEntry<String, String>>[
      MapEntry(isTagalog ? 'Booking ID' : 'Booking ID', bookingId),
      if (_hasBookingDetailValue(booking['date']))
        MapEntry(
          isTagalog ? 'Petsa' : 'Date',
          _bookingDetailValue(booking['date']),
        ),
      if (_hasBookingDetailValue(booking['time']))
        MapEntry(
          isTagalog ? 'Oras' : 'Time',
          _bookingDetailValue(booking['time']),
        ),
      if (_hasBookingDetailValue(booking['submittedAt']))
        MapEntry(
          isTagalog ? 'Ipinasa Noong' : 'Submitted',
          _bookingDetailValue(booking['submittedAt']),
        ),
    ];
    final hasDetailedInfo =
        bookingInfoItems.isNotEmpty ||
        groupedFields.values.any((items) => items.isNotEmpty) ||
        followUpNotes.isNotEmpty ||
        assignedPriest.isNotEmpty ||
        adminNotes.isNotEmpty;

    showResponsiveModal(
      context: context,
      padding: EdgeInsets.zero,
      builder: (context) {
        final isMobile = ParishBreakpoints.isMobile(context);
        final canProceedToPayment = _canProceedToPayment(sacramentType, status);

        return Container(
          constraints: BoxConstraints(
            maxWidth: isMobile ? MediaQuery.of(context).size.width * 0.9 : 500,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 12 : 16,
                  horizontal: isMobile ? 16 : 20,
                ),
                decoration: BoxDecoration(
                  color: ParishColors.primaryBlue,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking['sacramentType'] as String? ??
                            'Booking Details',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: ParishColors.primaryGold,
                      size: isMobile ? 18 : 20,
                    ),
                    SizedBox(width: isMobile ? 6 : 8),
                    Text(
                      isTagalog
                          ? 'Katayuan: ${_formatBookingStatus(isTagalog, status)}'
                          : 'Status: ${_formatBookingStatus(isTagalog, status)}',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: !hasDetailedInfo
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          child: Text(
                            isTagalog
                                ? 'Walang karagdagang detalye para sa booking na ito.'
                                : 'No additional details are available for this booking.',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: ParishColors.textGray600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        children: [
                          if (followUpNotes.isNotEmpty)
                            _buildBookingNoteSection(
                              isTagalog
                                  ? 'Mga Follow-up na Tala mula sa Parish Admin'
                                  : 'Follow-up Notes from Parish Admin',
                              followUpNotes,
                              isMobile,
                            ),
                          if (assignedPriest.isNotEmpty)
                            _buildBookingDetailSection(
                              isTagalog
                                  ? 'Itinalagang Pari'
                                  : 'Assigned Priest',
                              [
                                MapEntry(
                                  isTagalog ? 'Pari' : 'Priest',
                                  assignedPriest,
                                ),
                              ],
                              isMobile,
                            ),
                          if (adminNotes.isNotEmpty)
                            _buildBookingNoteSection(
                              isTagalog ? 'Admin Tala' : 'Admin Notes',
                              adminNotes,
                              isMobile,
                            ),
                          if (canProceedToPayment) ...[
                            Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: ParishColors.bgBlue50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: ParishColors.borderBlue100,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    isTagalog
                                        ? 'Ang iyong booking ay aprubado na. Pindutin ang "Magpatuloy sa Bayad" para makumpleto ang iyong reservation.'
                                        : 'Your booking is approved. Tap "Proceed to Payment" to complete your reservation.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: ParishColors.textGray700,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (amount > 0) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isTagalog
                                              ? 'Kabuuang Bayad'
                                              : 'Payment Total',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'PHP ${amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (isBaptism)
                                      Text(
                                        isSundayBooking
                                            ? (isTagalog
                                                  ? 'Presyo para sa Linggo: PHP ${_BookingFormFeeCache.instance.baptismAmount(isSunday: true)}'
                                                  : 'Sunday price: PHP ${_BookingFormFeeCache.instance.baptismAmount(isSunday: true)}')
                                            : (isTagalog
                                                  ? 'Presyo para sa Lunes hanggang Sabado: PHP ${_BookingFormFeeCache.instance.baptismAmount(isSunday: false)}'
                                                  : 'Monday to Saturday price: PHP ${_BookingFormFeeCache.instance.baptismAmount(isSunday: false)}'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: ParishColors.textGray700,
                                        ),
                                      ),
                                  ] else ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      isTagalog
                                          ? 'Hindi makuha ang kabuuang bayad para sa booking na ito.'
                                          : 'Unable to determine the total payment for this booking.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: ParishColors.textRed500,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () => _handleProceedToPayment(
                                      context,
                                      booking,
                                      bookingId,
                                      isTagalog,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ParishColors.primaryBlue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      isTagalog
                                          ? 'Magpatuloy sa Bayad'
                                          : 'Proceed to Payment',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isMobile ? 10 : 14),
                          ],
                          if (bookingInfoItems.isNotEmpty)
                            _buildBookingDetailSection(
                              isTagalog
                                  ? 'Impormasyon ng Booking'
                                  : 'Booking Information',
                              bookingInfoItems,
                              isMobile,
                            ),
                          if (groupedFields['booking']!.isNotEmpty)
                            _buildBookingDetailSection(
                              isTagalog
                                  ? 'Schedule at Serbisyo'
                                  : 'Schedule and Service',
                              groupedFields['booking']!,
                              isMobile,
                            ),
                          if (groupedFields['person']!.isNotEmpty)
                            _buildBookingDetailSection(
                              isTagalog
                                  ? 'Impormasyon ng Tao'
                                  : 'Person Information',
                              groupedFields['person']!,
                              isMobile,
                            ),
                          if (groupedFields['family']!.isNotEmpty)
                            _buildBookingDetailSection(
                              isTagalog
                                  ? 'Pamilya, Sponsors, at Godparents'
                                  : 'Family, Sponsors, and Godparents',
                              groupedFields['family']!,
                              isMobile,
                            ),
                          if (groupedFields['other']!.isNotEmpty)
                            _buildBookingDetailSection(
                              isTagalog
                                  ? 'Iba Pang Detalye'
                                  : 'Other Details',
                              groupedFields['other']!,
                              isMobile,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
