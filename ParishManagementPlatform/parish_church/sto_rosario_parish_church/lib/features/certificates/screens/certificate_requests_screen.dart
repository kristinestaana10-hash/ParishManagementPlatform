import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/responsive.dart';
import 'certificate_viewer_screen.dart';

class CertificateRequestsScreen extends StatefulWidget {
  final bool isTagalog;

  const CertificateRequestsScreen({super.key, this.isTagalog = false});

  @override
  State<CertificateRequestsScreen> createState() =>
      _CertificateRequestsScreenState();
}

class _CertificateRequestsScreenState extends State<CertificateRequestsScreen> {
  static const _types = <String, String>{
    'baptism': 'Baptismal Certificate',
    'confirmation': 'Confirmation/Kumpil Certificate',
    'marriage': 'Wedding/Marriage Certificate',
  };
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  late Future<List<Map<String, dynamic>>> _requests;
  final Set<String> _submitting = {};

  @override
  void initState() {
    super.initState();
    _requests = _loadRequests();
  }

  Future<List<Map<String, dynamic>>> _loadRequests() async {
    final result = await _functions
        .httpsCallable('getMyCertificateRequests')
        .call();
    final data = Map<String, dynamic>.from(result.data as Map);
    final certificates = (data['certificates'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    // Read attachments directly under the Firestore owner-only rule as well.
    // This lets the app show an attached file even before the callable is redeployed.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return certificates;
    final requestSnapshot = await FirebaseFirestore.instance
        .collection('certificate_requests')
        .where('userId', isEqualTo: uid)
        .get();
    final attachedFiles = <String, ({String url, String requestId, int timestamp})>{};
    for (final doc in requestSnapshot.docs) {
      final item = doc.data();
      final type = _certificateTypeKey(item['certificateType'] ?? item['type']);
      final url = item['softCopyUrl'];
      if (type == null || url is! String) continue;
      final uri = Uri.tryParse(url.trim());
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
      final date = item['requestDate'];
      final timestamp = date is Timestamp
          ? date.millisecondsSinceEpoch
          : date is DateTime
              ? date.millisecondsSinceEpoch
              : 0;
      final previous = attachedFiles[type];
      if (previous == null || timestamp >= previous.timestamp) {
        attachedFiles[type] = (
          url: url.trim(),
          requestId: doc.id,
          timestamp: timestamp,
        );
      }
    }
    return certificates.map((certificate) {
      final type = _certificateTypeKey(certificate['certificateType']);
      final attachment = type == null ? null : attachedFiles[type];
      return attachment == null
          ? certificate
          : {
              ...certificate,
              'softCopyUrl': attachment.url,
              'softCopyRequestId': attachment.requestId,
            };
    }).toList();
  }

  String? _certificateTypeKey(Object? value) {
    final type = value?.toString().trim().toLowerCase() ?? '';
    if (type.contains('baptis')) return 'baptism';
    if (type.contains('confirm') || type.contains('kumpil')) return 'confirmation';
    if (type.contains('marriage') || type.contains('wedding')) return 'marriage';
    return null;
  }

  Future<void> _request(String type) async {
    setState(() => _submitting.add(type));
    try {
      await _functions.httpsCallable('submitCertificateRequest').call({
        'certificateType': type,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request sent. Please monitor your request status.'),
        ),
      );
      setState(() => _requests = _loadRequests());
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? 'Unable to submit the certificate request.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting.remove(type));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ParishColors.bgBlue50,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: ParishColors.primaryBlue),
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final details = error is FirebaseFunctionsException
                ? '${error.code}: ${error.message ?? 'No error details returned.'}'
                : error.toString();
            return _MessagePanel(
              icon: Icons.cloud_off_outlined,
              message:
                  'Unable to load your church certificate records.\n\n$details',
              action: TextButton(
                onPressed: () => setState(() => _requests = _loadRequests()),
                child: const Text('Try again'),
              ),
            );
          }
          final byType = {
            for (final item in snapshot.data ?? const <Map<String, dynamic>>[])
              item['certificateType'] as String: item,
          };
          final availableTypes = _types.keys
              .where((type) => byType[type]?['available'] == true)
              .toList();
          return RefreshIndicator(
            color: ParishColors.primaryBlue,
            onRefresh: () async {
              final refreshed = _loadRequests();
              setState(() => _requests = refreshed);
              await refreshed;
            },
            child: ListView(
              padding: ParishResponsive.pagePadding(context),
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'My Church Certificates',
                    style: TextStyle(
                      fontSize: 24,
                      color: ParishColors.textBlue900,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (availableTypes.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No church certificate records are linked to your account yet. Please contact the parish office for assistance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ParishColors.textGray600,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  for (final entry in _types.entries)
                    if (byType[entry.key]?['available'] == true)
                    _buildCertificateCard(
                      entry.key,
                      entry.value,
                      byType[entry.key],
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCertificateCard(
    String type,
    String title,
    Map<String, dynamic>? data,
  ) {
    final available = data?['available'] == true;
    final status = data?['status'] as String?;
    final softCopyUrl = data?['softCopyUrl'] as String?;
    final softCopyRequestId = data?['softCopyRequestId'] as String?;
    final requestDate = data?['requestDate'] as String?;
    final parsedDate = requestDate == null ? null : DateTime.tryParse(requestDate);
    final normalizedStatus = status?.trim().toLowerCase();
    final statusDescription = switch (normalizedStatus) {
      'request sent' => 'Your request has been successfully submitted to the parish.',
      'processing' => 'The parish secretary is currently processing your request.',
      'completed' => 'Your certificate request is complete and ready based on the parish release procedure.',
      'ready to pick up' || 'ready for pickup' || 'ready to pickup' =>
        'Your certificate is ready to pick up at the parish office.',
      _ => null,
    };
    final statusColor = switch (normalizedStatus) {
      'completed' || 'ready to pick up' || 'ready for pickup' || 'ready to pickup' => ParishColors.greenSuccessDark,
      'processing' => ParishColors.primaryBlue,
      _ => ParishColors.darkGold,
    };
    final icon = switch (type) {
      'baptism' => Icons.water_drop_outlined,
      'confirmation' => Icons.local_fire_department_outlined,
      _ => Icons.favorite_border,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: ParishColors.bgWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParishColors.borderBlue100),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C1E3A8A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ParishColors.bgBlue50,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: ParishColors.primaryBlue, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: ParishColors.textBlue900,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (status != null)
                  _StatusBadge(status: status, color: statusColor),
              ],
            ),
            const SizedBox(height: 15),
            if (status != null) ...[
              Text(
                statusDescription ?? '',
                style: const TextStyle(
                  color: ParishColors.textGray600,
                  height: 1.4,
                ),
              ),
              if (parsedDate != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 17,
                      color: ParishColors.textGray500,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Request date: ${parsedDate.toLocal().toString().split(' ').first}',
                      style: const TextStyle(color: ParishColors.textGray600),
                    ),
                  ],
                ),
              ],
              if (status == 'Request Sent') ...[
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ParishColors.bgBlue50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ParishColors.borderBlue100),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: ParishColors.primaryBlue,
                        size: 19,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Certificate requests may take approximately 1–2 weeks to process. Please monitor your request status for updates from the parish.',
                          style: TextStyle(
                            color: ParishColors.textBlue900,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else if (available) ...[
              const Text(
                'A matching certificate record is available in the parish registry.',
                style: TextStyle(color: ParishColors.textGray600, height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ParishColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submitting.contains(type)
                      ? null
                      : () => _request(type),
                  icon: _submitting.contains(type)
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 19),
                  label: const Text('Request Certificate'),
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFEF3C7)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: ParishColors.darkGold,
                      size: 19,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'No certificate record is currently available for this certificate type. Please contact the parish office for assistance.',
                        style: TextStyle(
                          color: ParishColors.textGray700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (softCopyUrl != null &&
                softCopyUrl.isNotEmpty &&
                softCopyRequestId != null &&
                softCopyRequestId.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CertificateViewerScreen(title: title, requestId: softCopyRequestId))), icon: const Icon(Icons.visibility_outlined), label: const Text('View soft copy'))),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _MessagePanel({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ParishColors.borderBlue100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ParishColors.primaryBlue, size: 36),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ParishColors.textGray700),
            ),
            if (action != null) action!,

          ],
        ),
      ),
    );
  }
}
