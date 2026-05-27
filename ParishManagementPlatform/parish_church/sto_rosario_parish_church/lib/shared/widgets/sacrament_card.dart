import 'package:flutter/material.dart';
import '../../core/design/colors.dart';

class SacramentCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData? icon;
  final String? assetPath;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final bool isMobile;

  const SacramentCard({
    super.key,
    required this.title,
    required this.description,
    this.icon,
    this.assetPath,
    required this.gradient,
    required this.onTap,
    this.isMobile = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient top bar
            Container(
              height: 8,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16.0),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Icon / Asset logo
                      Container(
                        width: isMobile ? 110 : 130,
                        height: isMobile ? 110 : 130,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: assetPath != null
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  assetPath!,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Icon(
                                icon ?? Icons.church,
                                color: Colors.white,
                                size: isMobile ? 56 : 64,
                              ),
                      ),
                      const SizedBox(height: 12.0),
                      // Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: ParishColors.textBlue900,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8.0),
                      // Description
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ParishColors.textGray600,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
