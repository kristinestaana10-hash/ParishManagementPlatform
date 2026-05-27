import 'package:flutter/material.dart';
import '../../core/design/colors.dart';

class ParishHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationPressed;
  final VoidCallback onLanguagePressed;
  final VoidCallback onLogoutPressed;
  final int notificationCount;
  final String userName;
  final String userStatus;
  final bool isDesktop;

  const ParishHeaderBar({
    super.key,
    required this.onMenuPressed,
    required this.onNotificationPressed,
    required this.onLanguagePressed,
    required this.onLogoutPressed,
    this.notificationCount = 0,
    this.userName = 'Juan Dela Cruz',
    this.userStatus = 'Aktibong Parokiyano',
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(
          bottom: BorderSide(color: ParishColors.borderBlue100, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Menu Button + Profile
            Expanded(
              child: Row(
                children: [
                  // Menu button (mobile only)
                  if (!isDesktop)
                    IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: ParishColors.primaryBlue,
                      ),
                      onPressed: onMenuPressed,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12.0),
                  // Profile picture with yellow ring
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ParishColors.primaryGold.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Container(
                        color: ParishColors.bgBlue50,
                        child: const Icon(
                          Icons.person,
                          color: ParishColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  // User name and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: ParishColors.textBlue900,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          userStatus,
                          style: const TextStyle(
                            fontSize: 12,
                            color: ParishColors.textGray600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Right: Language, Notification, Logout
            Row(
              children: [
                // Language Toggle
                IconButton(
                  icon: const Icon(
                    Icons.language,
                    color: ParishColors.primaryBlue,
                    size: 20,
                  ),
                  onPressed: onLanguagePressed,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
                // Notification with badge
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: ParishColors.primaryBlue,
                        size: 20,
                      ),
                      onPressed: onNotificationPressed,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                    if (notificationCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ParishColors.primaryGold,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                // Logout (Desktop only)
                if (isDesktop)
                  TextButton.icon(
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Logout'),
                    onPressed: onLogoutPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: ParishColors.textBlue900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}
