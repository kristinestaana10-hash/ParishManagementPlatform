import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'core/design/colors.dart';
import 'core/design/gradients.dart';
import 'core/design/responsive.dart';
import 'core/services/firebase_service.dart';
import 'features/auth/landing_page.dart';
import '../shared/widgets/header_bar.dart';
import '../shared/widgets/bottom_nav_bar.dart';
import '../shared/widgets/sidebar_drawer.dart';
import '../features/home/screens/home_screen.dart';
import '../features/sacraments/screens/sacrament_form_screen.dart';
import '../features/sacraments/widgets/sacrament_description_modal.dart';
import '../features/bookings/screens/bookings_screen.dart';
import '../features/ai_chat/screens/ai_chat_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/history/screens/church_history_screen.dart';
import '../features/masses/screens/mass_schedule_screen.dart';
import '../features/donations/screens/donation_feature.dart';
import '../features/contact/screens/contact_screen.dart';
import '../features/announcements/screens/announcements_screen.dart';

void _showModalNotificationGlobal(
  BuildContext context,
  String message, {
  Color bgColor = Colors.blue,
}) {
  bool isDialogOpen = true;
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor.withValues(alpha: 0.2),
              ),
              child: Icon(
                bgColor == ParishColors.greenSuccess
                    ? Icons.check_circle
                    : bgColor == Colors.red
                    ? Icons.error
                    : Icons.info,
                color: bgColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 16,
                  color: ParishColors.textBlue900,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ).then((_) => isDialogOpen = false);

  // Auto-dismiss after 2 seconds
  Future.delayed(const Duration(seconds: 2), () {
    if (isDialogOpen && Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  });
}

class ParishionerDashboard extends StatefulWidget {
  final String userName;
  final bool isGuest;

  const ParishionerDashboard({
    super.key,
    this.userName = 'Juan Dela Cruz',
    this.isGuest = false,
  });

  @override
  State<ParishionerDashboard> createState() => _ParishionerDashboardState();
}

class _ParishionerDashboardState extends State<ParishionerDashboard> {
  int _currentNavIndex = 0;
  int _bookingsCount = 0;
  bool _isLanguageTagalog = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _bookingsSubscription;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    if (!_isGuest) {
      _bookingsSubscription = FirebaseService.instance
          .userBookingsStream()
          .listen((snapshot) {
            setState(() {
              _bookingsCount = snapshot.docs.length;
            });
          });
    }
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  bool get _isGuest =>
      widget.isGuest || widget.userName.toLowerCase().contains('guest');

  @override
  Widget build(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: ParishHeaderBar(
        onMenuPressed: () {
          if (isMobile) {
            _scaffoldKey.currentState?.openDrawer();
          }
        },
        onNotificationPressed: _showNotifications,
        onLanguagePressed: _toggleLanguage,
        onLogoutPressed: _logout,
        notificationCount: 3,
        userName: widget.userName,
        userStatus: _isGuest
            ? (_isLanguageTagalog ? 'Bisita' : 'Guest')
            : (_isLanguageTagalog
                  ? 'Aktibong Parokiyano'
                  : 'Active Parishioner'),
        isDesktop: !isMobile,
      ),
      drawer: isMobile
          ? ParishSidebarDrawer(
              onAboutParishPressed: _navigateToAboutParish,
              onMassSchedulePressed: _navigateToMassSchedule,
              onAnnouncementsPressed: _navigateToAnnouncements,
              onDonatePressed: _navigateToDonate,
              onContactPressed: _navigateToContact,
              onSignInPressed: _showAuthDialog,
              isGuest: _isGuest,
            )
          : null,
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAIChat,
        backgroundColor: ParishColors.primaryBlue,
        tooltip: _isLanguageTagalog ? 'Parish Assistant' : 'Parish Assistant',
        child: const Icon(Icons.chat_bubble, color: Colors.white),
      ),
      bottomNavigationBar: isMobile
          ? ParishBottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: _onNavTap,
              bookingsCount: _bookingsCount,
              isGuest: _isGuest,
            )
          : null,
    );
  }

  void _navigateToAnnouncements() {
    // Close the drawer
    _scaffoldKey.currentState?.closeDrawer();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AnnouncementsScreen(isTagalog: _isLanguageTagalog),
      ),
    );
  }

  String _t(String tagalog, String english) {
    return _isLanguageTagalog ? tagalog : english;
  }

  void _showModalNotification(String message, {Color bgColor = Colors.blue}) {
    bool isDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bgColor.withValues(alpha: 0.2),
                ),
                child: Icon(
                  bgColor == ParishColors.greenSuccess
                      ? Icons.check_circle
                      : bgColor == Colors.red
                      ? Icons.error
                      : Icons.info,
                  color: bgColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: ParishColors.textBlue900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => isDialogOpen = false);

    // Auto-dismiss after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && isDialogOpen) {
        Navigator.of(context).pop();
      }
    });
  }

  Widget _showSacramentDialog(SacramentType sacramentType) {
    return SacramentFormScreen(
      sacramentType: sacramentType,
      isTagalog: _isLanguageTagalog,
    );
    switch (_currentNavIndex) {
      case 0:
        return HomeScreen(
          userName: widget.userName,
          isTagalog: _isLanguageTagalog,
          isGuest: _isGuest,
          onSacramentTap: (sacramentType) {
            showDialog(
              context: context,
              barrierDismissible: true,
            builder: (context) => SacramentDescriptionModal(
              sacramentType: sacramentType,
              isTagalog: _isLanguageTagalog,
              canBook: !_isGuest,
              onBook: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) {
                      final size = MediaQuery.of(context).size;
                      return Dialog(
                        insetPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: size.width < 600 ? size.width * 0.92 : 560,
                            maxHeight: size.height * 0.84,
                          ),
                          child: _showSacramentDialog(sacramentType),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      case 1:
        return BookingsScreen(
          isTagalog: _isLanguageTagalog,
          onStartBooking: () => _onNavTap(0),
        );
      case 2:
        return ProfileScreen(
          userName: widget.userName,
          onLogoutPressed: _logout,
          isTagalog: _isLanguageTagalog,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _onNavTap(int index) {
    setState(() {
      // Guest nav has 2 tabs, others have 4
      final maxIndex = _isGuest ? 1 : 3;
      _currentNavIndex = index.clamp(0, maxIndex);
    });
  }

  Widget _buildBody() {
    if (_isGuest) {
      switch (_currentNavIndex) {
        case 0:
          return HomeScreen(
            userName: widget.userName,
            isTagalog: _isLanguageTagalog,
            isGuest: _isGuest,
            onSacramentTap: (sacramentType) {
              showDialog(
                context: context,
                barrierDismissible: true,
                builder: (context) => SacramentDescriptionModal(
                  sacramentType: sacramentType,
                  isTagalog: _isLanguageTagalog,
                  canBook: false,
                  onBook: () {
                    _showModalNotification(
                      _t(
                        'Bilang bisita, hindi ka makakapag-book ng sakramento. Mag-log in o mag-sign up upang magpatuloy.',
                        'As a guest, you cannot book sacraments. Please log in or sign up to continue.',
                      ),
                      bgColor: Colors.red,
                    );
                  },
                ),
              );
            },
          );
        case 1:
          return DonationFeature(
            isTagalog: _isLanguageTagalog,
            isGuest: _isGuest,
          );
        default:
          return const SizedBox.shrink();
      }
    }

    switch (_currentNavIndex) {
      case 0:
        return HomeScreen(
          userName: widget.userName,
          isTagalog: _isLanguageTagalog,
          isGuest: _isGuest,
          onSacramentTap: (sacramentType) {
            showDialog(
              context: context,
              barrierDismissible: true,
            builder: (context) => SacramentDescriptionModal(
              sacramentType: sacramentType,
              isTagalog: _isLanguageTagalog,
              canBook: true,
              onBook: () {
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (context) {
                      final size = MediaQuery.of(context).size;
                      return Dialog(
                        insetPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        backgroundColor: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: size.width < 600 ? size.width * 0.92 : 560,
                            maxHeight: size.height * 0.84,
                          ),
                          child: _showSacramentDialog(sacramentType),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      case 1:
        return DonationFeature(
          isTagalog: _isLanguageTagalog,
          isGuest: _isGuest,
        );
      case 2:
        return BookingsScreen(
          isTagalog: _isLanguageTagalog,
          onStartBooking: () => _onNavTap(0),
        );
      case 3:
        return ProfileScreen(
          userName: widget.userName,
          onLogoutPressed: _logout,
          isTagalog: _isLanguageTagalog,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<BaptismTypeChoice?> _showBaptismTypeSelectionDialog(
    BuildContext context,
    bool isTagalog,
  ) {
    BaptismTypeChoice selectedChoice = BaptismTypeChoice.private;

    return showDialog<BaptismTypeChoice>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                isTagalog ? 'Pumili ng Uri ng Binyag' : 'Choose Baptism Type',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<BaptismTypeChoice>(
                    contentPadding: EdgeInsets.zero,
                    value: BaptismTypeChoice.private,
                    groupValue: selectedChoice,
                    onChanged: (value) {
                      setState(() {
                        selectedChoice = value!;
                      });
                    },
                    title: Text(
                      isTagalog
                          ? 'Pribadong Binyag - ₱1,650'
                          : 'Private Baptism - ₱1,650',
                    ),
                    subtitle: Text(
                      isTagalog
                          ? 'Maaaring mag-book anumang araw.'
                          : 'Can be booked on any day.',
                    ),
                  ),
                  RadioListTile<BaptismTypeChoice>(
                    contentPadding: EdgeInsets.zero,
                    value: BaptismTypeChoice.public,
                    groupValue: selectedChoice,
                    onChanged: (value) {
                      setState(() {
                        selectedChoice = value!;
                      });
                    },
                    title: Text(
                      isTagalog
                          ? 'Public Binyag - ₱300 (Linggo lamang)'
                          : 'Public Baptism - ₱300 (Sunday only)',
                    ),
                    subtitle: Text(
                      isTagalog
                          ? 'Available lamang tuwing Linggo.'
                          : 'Available only on Sundays.',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    isTagalog ? 'Kanselahin' : 'Cancel',
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selectedChoice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ParishColors.primaryBlue,
                  ),
                  child: Text(
                    isTagalog ? 'Magpatuloy' : 'Continue',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSacramentFormDialog(
    SacramentType sacramentType, {
    BaptismTypeChoice? initialBaptismType,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 0,
        ),
        backgroundColor: Colors.transparent,
        child: SacramentFormScreen(
          sacramentType: sacramentType,
          isTagalog: _isLanguageTagalog,
          initialBaptismType: initialBaptismType,
        ),
      ),
    );
  }

  void _showNotifications() {
    _showModalNotification(_t('Walang bagong abiso', 'No new notifications'));
  }

  void _showAIChat() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ParishColors.primaryBlue,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.chat_bubble,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _t('Parish Assistant', 'Parish Assistant'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Chat content
              Expanded(child: AIChatScreen(isTagalog: _isLanguageTagalog)),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleLanguage() {
    setState(() {
      _isLanguageTagalog = !_isLanguageTagalog;
    });
    _showModalNotification(
      _isLanguageTagalog ? 'Tagalog' : 'English',
      bgColor: ParishColors.primaryBlue,
    );
  }

  void _navigateToAboutParish() {
    // Close the drawer
    _scaffoldKey.currentState?.closeDrawer();

    // Navigate to the About Parish page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChurchHistoryScreen(isTagalog: _isLanguageTagalog),
      ),
    );
  }

  void _navigateToMassSchedule() {
    // Close the drawer
    _scaffoldKey.currentState?.closeDrawer();

    // Navigate to the Mass Schedule page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MassScheduleScreen(isTagalog: _isLanguageTagalog),
      ),
    );
  }

  void _navigateToDonate() {
    // Close the drawer
    _scaffoldKey.currentState?.closeDrawer();

    // Navigate to the Donation page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DonationFeature(isTagalog: _isLanguageTagalog, isGuest: _isGuest),
      ),
    );
  }

  void _navigateToContact() {
    // Close the drawer
    _scaffoldKey.currentState?.closeDrawer();

    // Navigate to the Contact page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactScreen(isTagalog: _isLanguageTagalog),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_t('Mag-logout', 'Log out')),
        content: Text(
          _t(
            'Sigurado ka na bang gusto mong mag-logout?',
            'Are you sure you want to log out?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('Kanselahin', 'Cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseService.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LandingPage()),
              );
            },
            child: Text(_t('Mag-logout', 'Log out')),
          ),
        ],
      ),
    );
  }

  void _showAuthDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    gradient: ParishGradients.blueHeroGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20.0),
                      topRight: Radius.circular(20.0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.2),
                          border: Border.all(
                            color: ParishColors.primaryGold,
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'lib/imgs/logo.jpeg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isLanguageTagalog
                            ? 'Maligayang pagdating sa Sto. Rosario Parish Church'
                            : 'Welcome to Sto. Rosario Parish Church',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Sign Up Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showSignupModal();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ParishColors.primaryGold,
                      foregroundColor: ParishColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black.withValues(alpha: 0.3),
                    ),
                    child: Text(
                      _isLanguageTagalog ? 'Mag-sign up' : 'Sign Up',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Log In Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showLoginModal();
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: ParishColors.primaryBlue,
                        width: 2,
                      ),
                      foregroundColor: ParishColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                    ),
                    child: Text(
                      _isLanguageTagalog ? 'Mag-log in' : 'Log In',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSignupModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return SignupModal(
          onSignup: _navigateToDashboardFromAuth,
          isTagalog: _isLanguageTagalog,
        );
      },
    );
  }

  void _showLoginModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return LoginModal(
          onLogin: _navigateToDashboardFromAuth,
          isTagalog: _isLanguageTagalog,
        );
      },
    );
  }

  void _navigateToDashboardFromAuth(String userName) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ParishionerDashboard(userName: userName, isGuest: false),
      ),
    );
  }
}

