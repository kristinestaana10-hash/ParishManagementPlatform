import 'dart:math' as math;

import 'package:flutter/material.dart';

class ParishBreakpoints {
  static const double mobileMax = 600;
  static const double tabletMax = 1024;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= mobileMax && w < tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMax;
}

class ParishResponsive {
  static double clampTextScale(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final systemScale = MediaQuery.textScalerOf(context).scale(1.0);

    final upper = w >= ParishBreakpoints.tabletMax ? 1.2 : 1.35;
    return systemScale.clamp(1.0, upper);
  }

  static EdgeInsets pagePadding(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= ParishBreakpoints.tabletMax) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    if (w >= ParishBreakpoints.mobileMax) {
      return const EdgeInsets.all(20);
    }
    return const EdgeInsets.all(16);
  }

  static double maxContentWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1440) return 1200;
    if (w >= ParishBreakpoints.tabletMax) return 1000;
    return w;
  }

  static int gridColumns(
    BuildContext context, {
    int mobile = 2,
    int tablet = 2,
    int desktop = 3,
  }) {
    final w = MediaQuery.of(context).size.width;
    if (w >= ParishBreakpoints.tabletMax) return desktop;
    if (w >= ParishBreakpoints.mobileMax) return tablet;
    return mobile;
  }

  static double clampDouble(double value, double min, double max) {
    return math.min(max, math.max(min, value));
  }
}

class ParishResponsiveScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const ParishResponsiveScaffold({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final maxWidth = ParishResponsive.maxContentWidth(context);
    final scaffoldPadding = padding ?? ParishResponsive.pagePadding(context);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: scaffoldPadding, child: child),
      ),
    );
  }
}
