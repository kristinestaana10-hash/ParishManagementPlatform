import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'core/services/firebase_service.dart';
import 'core/design/theme.dart';
import 'core/design/responsive.dart';
import 'features/auth/landing_page.dart';
import 'firebase_options.dart';
import 'parishioner_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _appLinks = AppLinks();
  final _handledPaymentReturns = <String>{};
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleIncomingLink);
    _appLinks.getInitialLink().then((link) {
      if (link != null) _handleIncomingLink(link);
    });
  }

  Future<void> _handleIncomingLink(Uri link) async {
    if (link.scheme != 'storosarioparish' || link.host != 'payment-return') {
      return;
    }
    final paymentId = link.queryParameters['payment_id']?.trim() ?? '';
    final paymentType = link.queryParameters['payment_type']?.trim() ?? '';
    if (paymentId.isEmpty ||
        !const {
          'donation',
          'donationDrive',
          'offering',
        }.contains(paymentType)) {
      return;
    }

    final returnKey = '$paymentType:$paymentId';
    if (!_handledPaymentReturns.add(returnKey)) return;
    try {
      // Xendit can redirect the customer a moment before the paid state is
      // available to its API. Retry that verification briefly, but never
      // acknowledge a pending, cancelled, or failed payment as successful.
      var status = '';
      for (var attempt = 0; attempt < 5; attempt++) {
        status = await FirebaseService.instance.getVerifiedXenditPaymentStatus(
          paymentId: paymentId,
          paymentType: paymentType,
        );
        if (status != 'pending') break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      if (status != 'paid' || !mounted) return;

      // The navigator can still be mounting when Android/iOS delivers an
      // initial deep link, so wait until the first frame before showing it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _navigatorKey.currentContext;
        if (context == null || !mounted) return;
        final isOffering = paymentType == 'offering';
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Payment successful'),
            content: Text(
              isOffering
                  ? 'Thank you for your offering!'
                  : 'Thank you for your donation!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    } catch (_) {
      // A transient verification failure must never be represented as success.
      // The donor can return again after the connection is restored.
      _handledPaymentReturns.remove(returnKey);
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Sto. Rosario Parish Church',
      theme: ParishTheme.buildTheme(),
      builder: (context, child) {
        final scale = ParishResponsive.clampTextScale(context);
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          final userName = user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (user.email?.split('@').first ?? 'Parishioner');
          return ParishionerDashboard(userName: userName);
        }

        return const LandingPage();
      },
    );
  }
}
