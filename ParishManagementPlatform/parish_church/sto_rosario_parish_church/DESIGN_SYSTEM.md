# Parish Church App - Design System Documentation

## Overview

This document provides a comprehensive guide to the Sto. Rosario Parish Church Flutter application design system, including color palettes, spacing, components, and architectural patterns.

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry point
├── parishioner_dashboard.dart         # Main dashboard container
├── core/
│   └── design/
│       ├── colors.dart                # Color constants
│       ├── gradients.dart             # Gradient definitions
│       ├── spacing.dart               # Spacing & border radius
│       └── theme.dart                 # Material theme configuration
├── shared/
│   └── widgets/
│       ├── header_bar.dart            # App header component
│       ├── bottom_nav_bar.dart        # Bottom navigation (mobile)
│       ├── sidebar_drawer.dart        # Side menu drawer
│       ├── welcome_banner.dart        # Home screen welcome banner
│       └── sacrament_card.dart        # Reusable sacrament card
├── features/
│   ├── home/
│   │   └── screens/
│   │       └── home_screen.dart       # Home tab with sacraments
│   ├── bookings/
│   │   └── screens/
│   │       └── bookings_screen.dart   # Bookings management
│   ├── ai_chat/
│   │   └── screens/
│   │       └── ai_chat_screen.dart    # AI assistant chat
│   └── profile/
│       └── screens/
│           └── profile_screen.dart    # User profile & settings
```

## 🎨 Design System

### Color Palette

#### Primary Colors
- **Primary Blue**: `#1E40AF` (Blue-700) - Main brand color
- **Dark Blue**: `#1E3A8A` (Blue-800) - Darker variant
- **Light Blue**: `#3B82F6` (Blue-500) - Lighter variant
- **Accent Blue**: `#60A5FA` (Blue-400) - Accent color

#### Secondary Colors
- **Primary Gold**: `#FACC15` (Yellow-400) - Accent/highlights
- **Dark Gold**: `#EAB308` (Yellow-500) - Darker gold variant

#### Background Colors
- **Blue-50**: `#EFF6FF` - Light blue background
- **White**: `#FFFFFF` - Primary background
- **Gray-50**: `#F9FAFB` - Neutral background

#### Text Colors
- **Blue-900**: `#1E3A8A` - Primary text
- **Gray-600**: `#4B5563` - Secondary text
- **Gray-700**: `#374151` - Tertiary text
- **White**: `#FFFFFF` - Light text

#### Sacrament Colors
Each sacrament has its own gradient:
- **Baptism**: Blue-600 → Blue-700
- **Confirmation**: Amber → Orange
- **Wedding**: Blue-500 → Blue-600
- **Funeral**: Gray-500 → Gray-600
- **House Blessing**: Green-500 → Green-600
- **Anointing**: Purple-500 → Purple-600
- **Mass Intention**: Pink-500 → Pink-600

### Spacing System

```dart
xs    = 4.0px
sm    = 8.0px
md    = 12.0px
lg    = 16.0px
xl    = 20.0px
xxl   = 24.0px
xxxl  = 32.0px
```

### Border Radius

```dart
sm    = 8.0px
md    = 12.0px
lg    = 16.0px
xl    = 20.0px
xxl   = 24.0px
round = 9999.0px  // Circular
```

### Gradients

#### Hero Gradient
Blue gradient for headers and hero sections.

#### Button Gradient
Blue gradient for interactive elements.

#### Background Gradient
Subtle light blue to white gradient for backgrounds.

## 📱 Component Architecture

### Header Bar (`ParishHeaderBar`)

Fixed sticky header at the top of all screens.

**Features:**
- User profile picture with yellow ring
- User name and status
- Language toggle
- Notification bell with badge
- Logout button (desktop only)
- Menu button (mobile only)

**Props:**
```dart
- onMenuPressed: VoidCallback
- onNotificationPressed: VoidCallback
- onLanguagePressed: VoidCallback
- onLogoutPressed: VoidCallback
- notificationCount: int
- userName: String
- userStatus: String
- isDesktop: bool
```

### Bottom Navigation Bar (`ParishBottomNavBar`)

Mobile-only sticky bottom navigation with 4 tabs:
1. **Home** - Main dashboard
2. **Bookings** - Sacrament bookings with badge
3. **AI** - AI assistant chat
4. **Profile** - User profile & settings

**Features:**
- Active indicator (gradient bar on top)
- Badge counter for bookings
- Smooth transitions

### Sidebar Drawer (`ParishSidebarDrawer`)

Mobile drawer menu with quick access options:
- Settings
- About Parish
- Mass Schedule
- Notifications
- Donate
- Contact

### Welcome Banner (`WelcomeBanner`)

Hero banner on home screen with:
- Gradient overlay
- Church interior image
- Greeting message
- Active status indicator

### Sacrament Card (`SacramentCard`)

Reusable card for displaying sacrament services:
- Gradient top bar
- Icon with gradient background
- Title and description
- Tap to book functionality

## 🖥️ Screen Architecture

### Home Screen
- Welcome banner with personalized greeting
- Parish services grid (7 sacraments)
- Book sacrament functionality
- Responsive grid (2 columns on mobile/tablet, 2+ on desktop)

### Bookings Screen
- List of user's sacrament bookings
- Empty state with call-to-action
- Booking status tracking
- Details and cancellation options

### AI Chat Screen
- Chat interface with bot
- Message history
- Text input with send button
- Simulated AI responses

### Profile Screen
- User profile header with photo
- Contact information display
- Settings section (notifications, language)
- Password/security settings
- Logout button

## 🎯 Usage Examples

### Import Colors
```dart
import 'core/design/colors.dart';

Container(
  color: ParishColors.primaryBlue,
  child: Text(
    'Hello',
    style: TextStyle(color: ParishColors.textWhite),
  ),
)
```

### Import Gradients
```dart
import 'core/design/gradients.dart';

Container(
  decoration: BoxDecoration(
    gradient: ParishGradients.blueHeroGradient,
  ),
)
```

### Import Spacing
```dart
import 'core/design/spacing.dart';

Padding(
  padding: EdgeInsets.all(ParishSpacing.lg),
  child: Text('Hello'),
)
```

### Use ParishHeaderBar
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: ParishHeaderBar(
      onMenuPressed: () {},
      onNotificationPressed: () {},
      onLanguagePressed: () {},
      onLogoutPressed: () {},
    ),
    body: const Center(child: Text('Content')),
  );
}
```

## 🔄 Application Flow

1. **App starts** → `main.dart` initializes `MyApp`
2. **MyApp builds** → Uses `ParishTheme` and displays `ParishionerDashboard`
3. **Dashboard manages** → Navigation between 4 main tabs
4. **Each tab** → Displays respective screen (Home, Bookings, AI, Profile)
5. **Header & Nav** → Persistent across all screens for quick navigation

## 📐 Responsive Design

The app is designed to work on multiple screen sizes:

- **Mobile**: < 1024px
  - Uses bottom navigation bar
  - Shows drawer menu
  - Grid: 2 columns
  - Smaller fonts and spacing

- **Desktop**: >= 1024px
  - Shows sidebar navigation
  - No drawer menu
  - Grid: 2+ columns
  - Larger fonts and spacing
  - Logout button in header

## 🎨 Theming

Default theme applied via `ParishTheme.buildTheme()`:
- Primary Color: Parish Blue
- Secondary Color: Parish Gold
- Surface Color: White
- Font Family: Inter (or system default)

## 💡 Best Practices

1. **Always use design constants** instead of hardcoded values
2. **Maintain consistent spacing** using `ParishSpacing` class
3. **Use gradient definitions** for consistent visual hierarchy
4. **Import colors dynamically** for theme support
5. **Keep components reusable** and props-driven
6. **Test on multiple screen sizes** (mobile, tablet, desktop)

## 🚀 Future Enhancements

- [ ] Dark mode theme
- [ ] Additional languages (English, Spanish, etc.)
- [ ] Custom animations
- [ ] Advanced booking calendar
- [ ] Real AI integration
- [ ] Payment gateway integration
- [ ] Push notifications
- [ ] Offline support

## 📞 Support

For questions about the design system, please refer to the respective component documentation or reach out to the development team.
