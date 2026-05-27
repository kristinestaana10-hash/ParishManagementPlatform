import 'package:flutter/material.dart';
import '../../core/design/colors.dart';
import '../../core/design/gradients.dart';

class ParishBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int bookingsCount;
  final bool isGuest;

  const ParishBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.bookingsCount = 0,
    this.isGuest = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: ParishColors.borderBlue100, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: ParishColors.primaryBlue,
        unselectedItemColor: ParishColors.textGray600,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: isGuest
            ? [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined, size: 24),
                  activeIcon: _buildActiveIcon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.volunteer_activism_outlined, size: 24),
                  activeIcon: _buildActiveIcon(Icons.volunteer_activism),
                  label: 'Give',
                ),
              ]
            : [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home_outlined, size: 24),
                  activeIcon: _buildActiveIcon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.volunteer_activism_outlined, size: 24),
                  activeIcon: _buildActiveIcon(Icons.volunteer_activism),
                  label: 'Give',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.calendar_today_outlined, size: 24),
                  activeIcon: _buildActiveIcon(Icons.calendar_today),
                  label: 'Bookings',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.person_outline, size: 24),
                  activeIcon: _buildActiveIcon(Icons.person),
                  label: 'Profile',
                ),
              ],
      ),
    );
  }

  Widget _buildActiveIcon(IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 4,
          decoration: BoxDecoration(
            gradient: ParishGradients.primaryButtonGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 6),
        Icon(icon, size: 24),
      ],
    );
  }

  Widget _buildBookingsIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.calendar_today_outlined, size: 24),
        if (bookingsCount > 0)
          Positioned(
            top: -4,
            right: -12,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: ParishColors.primaryGold,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                '$bookingsCount',
                style: const TextStyle(
                  fontSize: 10,
                  color: ParishColors.textBlue900,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
