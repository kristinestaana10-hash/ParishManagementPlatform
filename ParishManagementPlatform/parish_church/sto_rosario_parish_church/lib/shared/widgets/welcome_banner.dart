import 'package:flutter/material.dart';
import '../../core/design/colors.dart';
import '../../core/design/gradients.dart';

class WelcomeBanner extends StatelessWidget {
  final String userName;
  final bool isMobile;
  final bool isTagalog;

  const WelcomeBanner({
    super.key,
    required this.userName,
    this.isMobile = true,
    this.isTagalog = true,
  });

  String _t(String tagalog, String english) {
    return isTagalog ? tagalog : english;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Church interior background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24.0),
                gradient: ParishGradients.blueHeroGradient,
              ),
            ),
          ),
          // Decorative blur circles
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: ParishColors.primaryGold.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: ParishColors.accentBlue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 24.0 : 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: ParishColors.primaryGold.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(9999.0),
                    border: Border.all(
                      color: ParishColors.primaryGold.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Pulsing indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ParishColors.primaryGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        _t('Aktibo Ngayon', 'Active Now'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
                // Greeting
                Text(
                  _t(
                    'Maligayang Pagbabalik, $userName!',
                    'Welcome Back, $userName!',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 24 : 40,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16.0),
                // Message
                Text(
                  _t(
                    'Ipagpatuloy ang iyong spiritual na paglalakbay: Mag-book ng mga sakramento, subaybayan ang iyong mga reservasyon, at manatiling konektado.',
                    'Continue your spiritual journey: Book sacraments, track your reservations, and stay connected.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 18,
                    color: ParishColors.blue200,
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
