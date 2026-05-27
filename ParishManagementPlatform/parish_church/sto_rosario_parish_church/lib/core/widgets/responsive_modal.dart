import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/responsive.dart';

class ResponsiveModal extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? maxWidth;
  final double? maxHeight;
  final bool scrollable;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final BoxShadow? boxShadow;
  final bool isFullscreenOnMobile;

  const ResponsiveModal({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.maxHeight,
    this.scrollable = true,
    this.borderRadius,
    this.backgroundColor,
    this.boxShadow,
    this.isFullscreenOnMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = ParishBreakpoints.isMobile(context);

    // Calculate responsive dimensions
    final modalWidth = maxWidth ?? _calculateModalWidth(screenSize.width);
    final modalHeight = maxHeight ?? _calculateModalHeight(screenSize.height);
    final modalPadding = padding ?? _calculateModalPadding(screenSize.width);
    final modalRadius =
        borderRadius ?? _calculateBorderRadius(screenSize.width);

    // For mobile fullscreen mode
    if (isMobile && isFullscreenOnMobile) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: screenSize.width,
          height: screenSize.height,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: modalPadding,
              child: scrollable ? SingleChildScrollView(child: child) : child,
            ),
          ),
        ),
      );
    }

    // Standard responsive modal
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: _calculateInsetPadding(screenSize.width),
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxWidth: modalWidth,
          maxHeight: modalHeight,
        ),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: modalRadius,
          boxShadow: [boxShadow ?? _calculateBoxShadow(screenSize.width)],
        ),
        child: scrollable
            ? SingleChildScrollView(padding: modalPadding, child: child)
            : Padding(padding: modalPadding, child: child),
      ),
    );
  }

  double _calculateModalWidth(double screenWidth) {
    if (screenWidth >= 1440) return 500;
    if (screenWidth >= ParishBreakpoints.tabletMax) return 450;
    if (screenWidth >= ParishBreakpoints.mobileMax) return 400;
    return screenWidth * 0.9;
  }

  double _calculateModalHeight(double screenHeight) {
    if (screenHeight >= 800) return screenHeight * 0.8;
    if (screenHeight >= 600) return screenHeight * 0.85;
    return screenHeight * 0.9;
  }

  EdgeInsets _calculateModalPadding(double screenWidth) {
    if (screenWidth >= ParishBreakpoints.tabletMax) {
      return const EdgeInsets.all(24);
    }
    if (screenWidth >= ParishBreakpoints.mobileMax) {
      return const EdgeInsets.all(20);
    }
    return const EdgeInsets.all(16);
  }

  BorderRadius _calculateBorderRadius(double screenWidth) {
    if (screenWidth >= ParishBreakpoints.tabletMax) {
      return BorderRadius.circular(24);
    }
    return BorderRadius.circular(20);
  }

  EdgeInsets _calculateInsetPadding(double screenWidth) {
    if (screenWidth >= ParishBreakpoints.tabletMax) {
      return const EdgeInsets.all(32);
    }
    if (screenWidth >= ParishBreakpoints.mobileMax) {
      return const EdgeInsets.all(24);
    }
    return const EdgeInsets.all(16);
  }

  BoxShadow _calculateBoxShadow(double screenWidth) {
    final blurRadius = screenWidth >= ParishBreakpoints.tabletMax ? 24.0 : 20.0;
    final spreadRadius = screenWidth >= ParishBreakpoints.tabletMax ? 2.0 : 1.0;

    return BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
      offset: Offset(0, blurRadius / 2),
    );
  }
}

class ResponsiveModalActions extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment alignment;
  final CrossAxisAlignment crossAlignment;
  final double spacing;

  const ResponsiveModalActions({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.end,
    this.crossAlignment = CrossAxisAlignment.center,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);

    // On mobile, stack buttons vertically
    if (isMobile && children.length > 1) {
      return Column(
        crossAxisAlignment: crossAlignment,
        children: children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;

          return Padding(
            padding: EdgeInsets.only(
              bottom: index < children.length - 1 ? spacing : 0,
            ),
            child: SizedBox(
              width: double.infinity, // Full width on mobile
              child: child,
            ),
          );
        }).toList(),
      );
    }

    // On tablet/desktop, keep horizontal layout
    return Row(
      mainAxisAlignment: alignment,
      crossAxisAlignment: crossAlignment,
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;

        return Padding(
          padding: EdgeInsets.only(left: index > 0 ? spacing : 0),
          child: child,
        );
      }).toList(),
    );
  }
}

// Helper method for showing responsive modals
Future<T?> showResponsiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool isFullscreenOnMobile = false,
  EdgeInsets? padding,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.5),
    barrierLabel: barrierLabel,
    useSafeArea: useSafeArea,
    builder: (context) => ResponsiveModal(
      isFullscreenOnMobile: isFullscreenOnMobile,
      padding: padding,
      child: Builder(builder: builder),
    ),
  );
}

// Responsive notification modal
Future<void> showResponsiveNotification({
  required BuildContext context,
  required String message,
  Color bgColor = ParishColors.primaryBlue,
  Duration duration = const Duration(seconds: 3),
}) {
  return showResponsiveModal(
    context: context,
    barrierDismissible: true,
    builder: (context) =>
        _NotificationModal(message: message, bgColor: bgColor),
  ).then((_) {
    // Auto-dismiss after duration
    Future.delayed(duration, () {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
    });
  });
}

class _NotificationModal extends StatelessWidget {
  final String message;
  final Color bgColor;

  const _NotificationModal({required this.message, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);
    final iconSize = isMobile ? 40.0 : 50.0;
    final fontSize = isMobile ? 14.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor.withValues(alpha: 0.2),
            ),
            child: Icon(
              _getIconForColor(bgColor),
              color: bgColor,
              size: iconSize * 0.6,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: fontSize,
                color: ParishColors.textBlue900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForColor(Color color) {
    if (color == ParishColors.greenSuccess) return Icons.check_circle;
    if (color == Colors.red) return Icons.error;
    return Icons.info;
  }
}
