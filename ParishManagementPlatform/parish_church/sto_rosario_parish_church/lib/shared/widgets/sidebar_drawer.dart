import 'package:flutter/material.dart';
import '../../core/design/colors.dart';
import '../../core/design/gradients.dart';

class ParishSidebarDrawer extends StatelessWidget {
  final VoidCallback onAboutParishPressed;
  final VoidCallback onMassSchedulePressed;
  final VoidCallback onAnnouncementsPressed;
  final VoidCallback onDonationDrivesPressed;
  final VoidCallback onDonatePressed;
  final VoidCallback onContactPressed;
  final VoidCallback? onSignInPressed;
  final bool isGuest;

  const ParishSidebarDrawer({
    super.key,
    required this.onAboutParishPressed,
    required this.onMassSchedulePressed,
    required this.onAnnouncementsPressed,
    required this.onDonationDrivesPressed,
    required this.onDonatePressed,
    required this.onContactPressed,
    this.onSignInPressed,
    this.isGuest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 300,
      child: Column(
        children: [
          // Header with gradient
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: ParishGradients.primaryButtonGradient,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                // Parish logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ParishColors.primaryGold.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Container(
                      color: ParishColors.bgBlue50,
                      child: const Icon(Icons.church, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Mabilis na Access',
                      style: TextStyle(
                        color: ParishColors.blue200,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                _buildMenuItem(
                  context,
                  Icons.info_outline,
                  'About Parish',
                  'Tungkol sa Parokya',
                  onAboutParishPressed,
                ),
                _buildMenuItem(
                  context,
                  Icons.calendar_month,
                  'Parish Schedule',
                  'Iskedyul ng Parokya',
                  onMassSchedulePressed,
                ),
                _buildMenuItem(
                  context,
                  Icons.campaign,
                  'Announcements',
                  'Mga Anunsyo',
                  onAnnouncementsPressed,
                ),
                _buildMenuItem(
                  context,
                  Icons.volunteer_activism,
                  'Donation Drives',
                  'Mga Donasyon',
                  onDonationDrivesPressed,
                ),
                _buildMenuItem(
                  context,
                  Icons.mail_outline,
                  'Contact',
                  'Makipag-ugnayan',
                  onContactPressed,
                ),
                if (isGuest)
                  _buildMenuItem(
                    context,
                    Icons.login,
                    'Sign In',
                    'Mag-sign in',
                    onSignInPressed ?? () {},
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String labelEn,
    String labelTl,
    VoidCallback onPressed,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            onPressed.call();
          },
          borderRadius: BorderRadius.circular(12.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ParishColors.borderBlue100,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(icon, color: ParishColors.primaryBlue, size: 20),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: Text(
                    labelEn,
                    style: const TextStyle(
                      fontSize: 14,
                      color: ParishColors.textBlue900,
                    ),
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
        ),
      ),
    );
  }
}
