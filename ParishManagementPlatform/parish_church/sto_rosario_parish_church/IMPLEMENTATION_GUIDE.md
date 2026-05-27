# Implementation Guide - Parish Church App

## Quick Start

This guide provides step-by-step instructions for getting the Sto. Rosario Parish Church Flutter app up and running.

## Prerequisites

- Flutter SDK (3.10.7 or later)
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for emulators)
- VS Code or similar IDE

## Setup

### 1. Clone/Navigate to Project
```bash
cd sto_rosario_parish_church
```

### 2. Get Dependencies
```bash
flutter pub get
```

### 3. Run the App
```bash
flutter run
```

For specific devices:
```bash
flutter run -d <device_id>
```

## Project File Organization

### Core Design Files
All design constants and theme configuration:
```
lib/core/design/
├── colors.dart        # 40+ color constants
├── gradients.dart     # 8 gradient definitions
├── spacing.dart       # Spacing & border radius
└── theme.dart         # Material theme setup
```

### Shared Widgets
Reusable components across the app:
```
lib/shared/widgets/
├── header_bar.dart        # Sticky top header (72px)
├── bottom_nav_bar.dart    # Mobile bottom navigation
├── sidebar_drawer.dart    # Mobile side menu
├── welcome_banner.dart    # Home welcome section
└── sacrament_card.dart    # Reusable sacrament card
```

### Feature Screens
Screen implementations:
```
lib/features/
├── home/screens/home_screen.dart           # 7 sacrament cards
├── bookings/screens/bookings_screen.dart   # Booking management
├── ai_chat/screens/ai_chat_screen.dart     # Chat interface
└── profile/screens/profile_screen.dart     # User profile
```

### Main App
```
lib/
├── main.dart                  # App entry point
└── parishioner_dashboard.dart # Dashboard container
```

## Key Features Implemented

### ✅ Design System
- 40+ color constants with semantic naming
- 8 gradient definitions for visual hierarchy
- Consistent spacing system (xs to xxxl)
- Material 3 theme configuration

### ✅ Component Library
- **ParishHeaderBar**: Sticky top with user info, notifications, language toggle
- **ParishBottomNavBar**: Mobile bottom navigation with active indicator
- **ParishSidebarDrawer**: Side menu for quick access
- **WelcomeBanner**: Personalized hero section
- **SacramentCard**: Reusable card for services

### ✅ Screens (4 Tabs)
1. **Home** - Parish services with 7 sacraments
2. **Bookings** - User bookings management
3. **AI Chat** - AI assistant interface
4. **Profile** - User info and settings

### ✅ Responsive Design
- Mobile-first approach
- Breakpoint at 1024px for desktop
- Adaptive navigation (drawer vs sidebar)
- Grid layouts for different screen sizes

## Adding New Features

### Add a New Sacrament Card
1. Define the gradient in `core/design/gradients.dart`
2. Add the color in `core/design/colors.dart` if needed
3. Create a `SacramentCard` in the grid

```dart
SacramentCard(
  title: 'Nuevo Sacramento',
  description: 'Descripción',
  icon: Icons.whatever,
  gradient: ParishGradients.yourGradient,
  onTap: () { /* navigate */ },
  isMobile: isMobile,
),
```

### Add a New Color
1. Open `core/design/colors.dart`
2. Add the constant with hexadecimal value

```dart
static const Color newColor = Color(0xFF123456);
```

### Add Navigation Item to Drawer
In `parishioner_dashboard.dart`, add to the drawer initialization:

```dart
_buildMenuItem(
  context,
  Icons.your_icon,
  'Label',
  'Tagalog Label',
  onYourActionPressed,
),
```

### Create a New Screen
1. Create folder: `lib/features/feature_name/screens/`
2. Create file: `feature_name_screen.dart`
3. Implement StatelessWidget or StatefulWidget
4. Add to TabBar navigation in `parishioner_dashboard.dart`

## Customization

### Change Theme Colors
Edit `core/design/theme.dart`:
```dart
class ParishTheme {
  static ThemeData buildTheme() {
    return ThemeData(
      primaryColor: ParishColors.yourColor,
      // ... other configurations
    );
  }
}
```

### Update Header User Info
In `parishioner_dashboard.dart`:
```dart
ParishHeaderBar(
  userName: 'Your Name',
  userStatus: 'Your Status',
  // ...
),
```

### Modify Spacing
Edit `core/design/spacing.dart` to adjust padding and margins throughout the app.

### Add Dark Mode
1. Create `dark_theme.dart` in `core/design/`
2. Implement `ThemeData` with dark colors
3. Use `MediaQuery` to detect system theme
4. Apply in main.dart

## Common Tasks

### Change Primary Color
```dart
// In core/design/colors.dart
static const Color primaryBlue = Color(0xFFYOURCOLOR);

// Automatically updates all UI elements using ParishColors.primaryBlue
```

### Update Language
```dart
// In parishioner_dashboard.dart
_toggleLanguage() updates _isLanguageTagalog bool
// Propagate to widgets via parameters
```

### Add Notification Badge Count
```dart
// In parishioner_dashboard.dart
ParishHeaderBar(
  notificationCount: 5,
  // ...
)

ParishBottomNavBar(
  bookingsCount: 3,
  // ...
)
```

### Handle Logout
Implement in `_logout()` method:
```dart
// Clear user data
// Navigate to login screen
Navigator.pushReplacementNamed(context, '/login');
```

## Troubleshooting

### Build Issues
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Hot Reload Not Working
```bash
# Full rebuild
flutter run --no-fast-start
```

### Missing Assets
Ensure `pubspec.yaml` has assets section:
```yaml
flutter:
  assets:
    - assets/images/
```

### Layout Issues
Use `MediaQuery` to debug:
```dart
print('Screen Width: ${MediaQuery.of(context).size.width}');
print('Is Mobile: ${MediaQuery.of(context).size.width < 1024}');
```

## Performance Tips

1. **Use `const` constructors** when possible
2. **Lazy load** screens when switching tabs
3. **Cache gradients** in constant definitions
4. **Optimize images** before adding to assets
5. **Use `RepaintBoundary`** for complex layouts
6. **Profile with DevTools** for performance analysis

## Testing

### Unit Tests
```bash
flutter test
```

### Widget Tests
```bash
flutter test test/widget_test.dart
```

### Integration Tests
```bash
flutter drive --target=test_driver/app.dart
```

## Deployment

### Android
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Material Design 3](https://m3.material.io)
- [Dart Documentation](https://dart.dev/guides)
- [Flutter Cookbook](https://flutter.dev/docs/cookbook)

## Support

For issues or questions:
1. Check DESIGN_SYSTEM.md for component documentation
2. Review example implementations
3. Refer to Flutter official documentation
4. Contact the development team

---

**Last Updated**: March 2026
**Version**: 1.0.0
