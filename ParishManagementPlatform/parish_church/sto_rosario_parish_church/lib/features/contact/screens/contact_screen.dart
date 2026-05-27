import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/gradients.dart';
import '../../../core/models/parish_profile.dart';
import '../../../core/services/firebase_service.dart';

class ContactScreen extends StatelessWidget {
  final bool isTagalog;

  const ContactScreen({super.key, this.isTagalog = true});

  String _t(String tagalog, String english) => isTagalog ? tagalog : english;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromRGBO(255, 255, 255, 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Color.fromRGBO(255, 255, 255, 0.5),
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
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color.fromRGBO(255, 255, 255, 0.2),
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
                    const SizedBox(height: 14),
                    Text(
                      _t('Makipag-ugnayan', 'Contact Us'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        'Sto. Rosario Parish Church',
                        'Sto. Rosario Parish Church',
                      ),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              child: StreamBuilder<ParishProfile?>(
                stream: FirebaseService.instance.getParishProfileStream(),
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  final phone = profile?.phone.trim().isNotEmpty == true
                      ? profile!.phone.trim()
                      : '(044) 761-1693\n0955-042-1977';
                  final email = profile?.email.trim().isNotEmpty == true
                      ? profile!.email.trim()
                      : 'sanjose.jaysantos@yahoo.com';
                  final priest = profile?.priest.trim().isNotEmpty == true
                      ? profile!.priest.trim()
                      : 'Rev. Fr. Jose Jay G. Santos - Parish Priest';
                  final currentPriest = profile?.currentPriest.trim().isNotEmpty == true
                      ? profile!.currentPriest.trim()
                      : 'Rev. Fr. Jose Jay G. Santos (2021 - Present)';
                  final massSchedule = profile?.massSchedule ?? [];
                  final officeSchedule = profile?.officeSchedule ?? [];
                  final hasSchedule = massSchedule.isNotEmpty || officeSchedule.isNotEmpty;
                  final primaryPhone = _primaryPhone(phone);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: ParishColors.bgBlue50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ParishColors.borderBlue100,
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t(
                                'Impormasyon sa Pakikipag-ugnayan',
                                'Contact Information',
                              ),
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: ParishColors.textBlue900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _t(
                                'Para sa anumang tanong, makipag-ugnayan sa amin sa mga sumusunod na detalye:',
                                'For any inquiries, reach out to us using the details below:',
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: ParishColors.textGray600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildContactCard(
                        icon: Icons.phone,
                        label: _t('Telepono', 'Phone'),
                        value: phone,
                        onTap: () => _launchPhone(primaryPhone),
                      ),
                      _buildContactCard(
                        icon: Icons.email,
                        label: _t('Email', 'Email'),
                        value: email,
                        onTap: () => _launchEmail(email),
                      ),
                      _buildContactCard(
                        icon: Icons.person,
                        label: _t('Pari', 'Priest'),
                        value: priest,
                      ),
                      _buildContactCard(
                        icon: Icons.person_outline,
                        label: _t('Kasalukuyang Pari', 'Current Priest'),
                        value: currentPriest,
                      ),
                      _buildContactCard(
                        icon: Icons.location_on,
                        label: _t('Tirahan', 'Address'),
                        value:
                            'CAGAYAN VALLEY RD.,\nMALIPAMPANG,\nSAN ILDEFONSO, BULACAN 3010',
                        onTap: () => _launchMaps(),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: ParishColors.bgBlue50,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: ParishColors.borderBlue100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('Oras ng Serbisyo', 'Service Hours'),
                              style: TextStyle(
                                fontSize: 16,
                                color: ParishColors.textBlue900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            if (!hasSchedule && snapshot.connectionState == ConnectionState.waiting)
                              const Center(child: CircularProgressIndicator())
                            else if (!hasSchedule)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildServiceHour(
                                    _t('Araw ng Linggo - Misa', 'Sunday Mass'),
                                    _t('6:30 AM, 8:00 AM', '6:30 AM, 8:00 AM'),
                                  ),
                                  _buildServiceHour(
                                    _t('Araw ng Linggo - Misa (Hapon)', 'Sunday Mass (Afternoon)'),
                                    '4:00 PM',
                                  ),
                                  _buildServiceHour(
                                    _t('Araw ng Linggo - Misa (Gabing)', 'Sunday Mass (Evening)'),
                                    '6:00 PM',
                                  ),
                                  _buildServiceHour(
                                    _t('Araw ng Sanlinggo - Misa', 'Weekday Mass'),
                                    _t('6:30 AM (Lunes-Sabado)', '6:30 AM (Mon-Sat)'),
                                  ),
                                ],
                              )
                            else ...[
                              () {
                                final seen = <String>{};
                                final massItems = <Map<String, String>>[];
                                final officeItems = <Map<String, String>>[];

                                for (final item in massSchedule) {
                                  final label = item.label(isTagalog).trim();
                                  final time = item.time.trim();
                                  final key = '$label|$time';
                                  if (label.isEmpty || time.isEmpty) continue;
                                  if (seen.add(key)) {
                                    massItems.add({'label': label, 'time': time});
                                  }
                                }

                                for (final item in officeSchedule) {
                                  final label = item.label(isTagalog).trim();
                                  final time = item.time.trim();
                                  final key = '$label|$time';
                                  if (label.isEmpty || time.isEmpty) continue;
                                  if (seen.add(key)) {
                                    officeItems.add({'label': label, 'time': time});
                                  }
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (final row in massItems)
                                      _buildServiceHour(row['label']!, row['time']!),
                                    if (officeItems.isNotEmpty) ...[
                                      const SizedBox(height: 12.0),
                                      Text(
                                        _t('Office Schedule', 'Office Schedule'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: ParishColors.textBlue900,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8.0),
                                      for (final row in officeItems)
                                        _buildServiceHour(row['label']!, row['time']!),
                                    ],
                                  ],
                                );
                              }(),
                            ],
                            const SizedBox(height: 16.0),
                            Text(
                              _t(
                                'Para sa karagdagang impormasyon, mangyaring tawagan kami o mag-email.',
                                'For additional information, please call us or send an email.',
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: ParishColors.textGray600,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: ParishColors.borderBlue100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: ParishColors.borderBlue100,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(icon, color: ParishColors.primaryBlue),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: ParishColors.textGray600,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: ParishColors.textBlue900,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: ParishColors.textGray600,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceHour(String service, String time) {
    final serviceText = service.trim();
    final timeText = time.trim();

    if (timeText.isEmpty || serviceText == timeText) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          serviceText,
          style: const TextStyle(
            fontSize: 14,
            color: ParishColors.textBlue900,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              serviceText,
              style: const TextStyle(
                fontSize: 14,
                color: ParishColors.textBlue900,
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Flexible(
            child: Text(
              timeText,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                color: ParishColors.textGray700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phoneNumber.replaceAll(RegExp(r'[^\d+]'), ''),
    );
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchMaps() async {
    const String address =
        'CAGAYAN VALLEY RD., MALIPAMPANG, SAN ILDEFONSO, BULACAN 3010';
    final Uri mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    if (await canLaunchUrl(mapsUri)) {
      await launchUrl(mapsUri);
    }
  }

  String _primaryPhone(String phone) {
    final parts = phone
        .split(RegExp(r'[\n/]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.first : phone.trim();
  }
}
