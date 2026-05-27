import 'dart:async';
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/design/colors.dart';
import '../../core/design/gradients.dart';
import '../../core/services/firebase_service.dart';
import '../../parishioner_dashboard.dart';

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

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final bool _isTagalog = false;
  void _showSignupModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return SignupModal(
          onSignup: _navigateToDashboard,
          isTagalog: _isTagalog,
        );
      },
    );
  }

  void _showLoginModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return LoginModal(onLogin: _navigateToDashboard, isTagalog: _isTagalog);
      },
    );
  }

  void _navigateToDashboard(String userName, {bool isGuest = false}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ParishionerDashboard(userName: userName, isGuest: isGuest),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/imgs/landingpage.jpeg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                ParishColors.primaryBlue.withValues(alpha: 0.4),
                ParishColors.primaryBlue.withValues(alpha: 0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with church logo/title
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Church logo
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(
                              color: ParishColors.primaryGold,
                              width: 3,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'lib/imgs/logo.jpeg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Church name
                        const Text(
                          'Parokya ng Mahal na\nBirhen ng Sto. Rosario',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Tagline
                        Text(
                          _isTagalog
                              ? 'Maligayang pagdating sa ating espirituwal na komunidad'
                              : 'Welcome to our spiritual community',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: ParishColors.blue200,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Sign Up Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _showSignupModal,
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
                              _isTagalog ? 'Mag-sign up' : 'Sign Up',
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
                            onPressed: _showLoginModal,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Colors.white,
                                width: 2,
                              ),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                            ),
                            child: Text(
                              _isTagalog ? 'Mag-log in' : 'Log In',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Guest access
                        TextButton(
                          onPressed: () =>
                              _navigateToDashboard('Guest', isGuest: true),
                          child: Text(
                            _isTagalog
                                ? 'Magpatuloy bilang Bisita'
                                : 'Continue as Guest',
                            style: TextStyle(
                              color: ParishColors.blue200,
                              fontSize: 16,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    ' 2026 Sto. Rosario Parish Church',
                    style: TextStyle(color: ParishColors.blue200, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Login Modal Dialog
class LoginModal extends StatefulWidget {
  final void Function(String) onLogin;
  final bool isTagalog;

  const LoginModal({super.key, required this.onLogin, this.isTagalog = false});

  @override
  State<LoginModal> createState() => _LoginModalState();
}

class _LoginModalState extends State<LoginModal> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final credential = await FirebaseService.instance.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final username =
          credential.user?.displayName ?? emailController.text.split('@').first;

      Navigator.of(context, rootNavigator: true).pop();
      widget.onLogin(username.isNotEmpty ? username : 'Guest');
    } on FirebaseAuthException catch (e) {
      debugPrint('Login error: ${e.code} ${e.message}');
      _showModalNotificationGlobal(
        context,
        '${e.code}: ${e.message ?? 'Login failed. Please try again.'}',
        bgColor: Colors.red,
      );
    } catch (e) {
      debugPrint('Login error: $e');
      _showModalNotificationGlobal(
        context,
        'Login failed. Please check your network and try again.',
        bgColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24.0),
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
                      widget.isTagalog ? 'Mag-log in' : 'Log In',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isTagalog
                          ? 'Maligayang pagbabalik sa ating komunidad'
                          : 'Welcome back to our community',
                      style: TextStyle(
                        fontSize: 14,
                        color: ParishColors.blue200,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Form
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      // Email field
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Email'
                              : 'Email Address',
                          prefixIcon: Icon(
                            Icons.email,
                            color: ParishColors.primaryGold,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog ? 'Password' : 'Password',
                          prefixIcon: Icon(
                            Icons.lock,
                            color: ParishColors.primaryGold,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: ParishColors.textGray600,
                            ),
                            onPressed: () {
                              setState(
                                () => obscurePassword = !obscurePassword,
                              );
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.primaryGold,
                            foregroundColor: ParishColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isTagalog ? 'Mag-log in' : 'Log In',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Forgot password
                      TextButton(
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) {
                                return ForgotPasswordModal(
                                  isTagalog: widget.isTagalog,
                                );
                              },
                            ),
                          );
                        },
                        child: Text(
                          widget.isTagalog
                              ? 'Nakalimutan ang Password?'
                              : 'Forgot Password?',
                          style: TextStyle(
                            color: ParishColors.primaryGold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Signup Modal Dialog
class SignupModal extends StatefulWidget {
  final void Function(String) onSignup;
  final bool isTagalog;

  const SignupModal({
    super.key,
    required this.onSignup,
    this.isTagalog = false,
  });

  @override
  State<SignupModal> createState() => _SignupModalState();
}

class _SignupModalState extends State<SignupModal> {
  final formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final birthdayController = TextEditingController();
  final otpController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  DateTime? selectedBirthday;
  bool acceptTerms = false;
  bool isVerifyingOtp = false;
  bool isResendingOtp = false;
  String otpErrorMessage = '';
  String? selectedBarangay;
  bool isMunicipalityProvinceReadOnly = false;

  static const List<String> _barangayOptions = [
    'PASONG BANGKAL',
    'SITIO PAG-ASA',
    'PULONG TAMO',
    'SAPANG PUTIK',
    'BAGONG SILANG',
    'BAGONG BARRIO',
    'UPIG',
    'TELAPATIO',
    'CALAWITAN',
    'MAASIM',
    'CALASAG',
    'Others',
  ];

  // Google Places API key
  static const String _googleApiKey = 'AIzaSyAoKG4IiO0--V0xgJjqSln2u1e-apsWYKY';

  // Address autocomplete
  List<dynamic> _addressSuggestions = [];
  bool _isLoadingAddressSuggestions = false;
  String? _addressApiError;
  Timer? _addressDebounceTimer;
  final FocusNode _addressFocusNode = FocusNode();

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    birthdayController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    otpController.dispose();
    _addressDebounceTimer?.cancel();
    _addressFocusNode.dispose();
    super.dispose();
  }

  // Address autocomplete methods
  void _onAddressChanged(String value) {
    _addressDebounceTimer?.cancel();

    // Clear previous errors when user types
    if (_addressApiError != null) {
      setState(() => _addressApiError = null);
    }

    if (value.length < 3) {
      setState(() => _addressSuggestions = []);
      return;
    }

    _addressDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchAddressSuggestions(value);
    });
  }

  Future<void> _fetchAddressSuggestions(String input) async {
    if (input.length < 3) return;

    setState(() {
      _isLoadingAddressSuggestions = true;
      _addressApiError = null;
    });

    try {
      debugPrint('Fetching address suggestions for: $input');
      // Using geocoding API instead of places autocomplete for better results
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(input)}'
        '&key=$_googleApiKey'
        '&components=country:PH'
        '&language=en',
      );

      final response = await http.get(url);
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Geocode API Status: ${data['status']}');
        debugPrint('Full response: $data');

        if (data['status'] == 'OK' && mounted) {
          final results = data['results'] as List? ?? [];
          debugPrint('Found ${results.length} geocode results');

          // Convert geocode results to format similar to places
          final suggestions = results
              .map(
                (result) => {
                  'description': result['formatted_address'],
                  'structured_formatting': {
                    'main_text':
                        result['address_components']?.first?['long_name'] ??
                        result['formatted_address'],
                    'secondary_text': result['formatted_address'],
                  },
                },
              )
              .toList();

          setState(() {
            _addressSuggestions = suggestions;
            _isLoadingAddressSuggestions = false;
          });
        } else {
          final errorMsg =
              'API Error: ${data['status']} - ${data['error_message'] ?? 'Check API key'}';
          debugPrint(errorMsg);
          if (mounted) {
            setState(() {
              _isLoadingAddressSuggestions = false;
              _addressSuggestions = [];
              _addressApiError = errorMsg;
            });
          }
        }
      } else {
        debugPrint('HTTP Error: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _isLoadingAddressSuggestions = false;
            _addressSuggestions = [];
            _addressApiError = 'HTTP Error: ${response.statusCode}';
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching address suggestions: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingAddressSuggestions = false;
          _addressSuggestions = [];
          _addressApiError = 'Network error: $e';
        });
      }
    }
  }

  void _selectAddressSuggestion(dynamic suggestion) {
    addressController.text = suggestion['description'] ?? '';
    setState(() => _addressSuggestions = []);
    _addressFocusNode.unfocus();
  }

  String _formatBirthday(DateTime birthday) {
    return '${birthday.month.toString().padLeft(2, '0')}/${birthday.day.toString().padLeft(2, '0')}/${birthday.year}';
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initialDate = selectedBirthday ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => child ?? const SizedBox.shrink(),
    );

    if (picked != null) {
      setState(() {
        selectedBirthday = picked;
        birthdayController.text = _formatBirthday(picked);
      });
    }
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional during signup
    }
    // Must be exactly 11 digits starting with 09
    if (value.length != 11 || !value.startsWith('09')) {
      return widget.isTagalog
          ? 'Invalid format. Gamitin: 09XXXXXXXXX (11 digits)'
          : 'Invalid format. Use: 09XXXXXXXXX (11 digits)';
    }
    return null;
  }

  Future<bool> _showOtpDialog() async {
    otpController.clear();
    otpErrorMessage = '';

    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> handleVerify() async {
              setDialogState(() {
                isVerifyingOtp = true;
                otpErrorMessage = '';
              });

              try {
                await FirebaseService.instance.verifySignupOtpAndCreateAccount(
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  email: emailController.text.trim(),
                  password: passwordController.text,
                  otp: otpController.text.trim(),
                  phone: phoneController.text.trim(),
                  address: addressController.text.trim(),
                  barangay: selectedBarangay,
                  birthday: selectedBirthday,
                );
                Navigator.of(dialogContext).pop(true);
                return;
              } on FirebaseFunctionsException catch (e) {
                setDialogState(() {
                  otpErrorMessage = e.message ?? 'OTP verification failed.';
                });
              } on FirebaseAuthException catch (e) {
                setDialogState(() {
                  otpErrorMessage = e.message ?? 'OTP verification failed.';
                });
              } catch (_) {
                setDialogState(() {
                  otpErrorMessage =
                      'OTP verification failed. Please try again.';
                });
              } finally {
                setDialogState(() {
                  isVerifyingOtp = false;
                });
              }
            }

            Future<void> handleResend() async {
              setDialogState(() {
                isResendingOtp = true;
                otpErrorMessage = '';
              });
              try {
                await FirebaseService.instance.requestSignupOtp(
                  email: emailController.text.trim(),
                );
                if (!mounted) return;
                _showModalNotificationGlobal(
                  context,
                  'A new OTP code was sent to your email.',
                  bgColor: ParishColors.greenSuccess,
                );
              } on FirebaseFunctionsException catch (e) {
                setDialogState(() {
                  otpErrorMessage = e.message ?? 'Unable to resend OTP.';
                });
              } catch (_) {
                setDialogState(() {
                  otpErrorMessage = 'Unable to resend OTP. Please try again.';
                });
              } finally {
                setDialogState(() {
                  isResendingOtp = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Verify Email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter the 6-digit OTP code we sent to your email.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'OTP Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (otpErrorMessage.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      otpErrorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isResendingOtp || isVerifyingOtp
                      ? null
                      : handleResend,
                  child: isResendingOtp
                      ? const Text('Resending...')
                      : const Text('Resend Code'),
                ),
                ElevatedButton(
                  onPressed: isVerifyingOtp || isResendingOtp
                      ? null
                      : handleVerify,
                  child: isVerifyingOtp
                      ? const Text('Verifying...')
                      : const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );
    return result == true;
  }

  Future<void> handleSignup() async {
    if (!formKey.currentState!.validate()) return;

    if (!acceptTerms) {
      _showModalNotificationGlobal(
        context,
        'Please accept the terms and conditions',
        bgColor: Colors.red,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseService.instance.requestSignupOtp(
        email: emailController.text.trim(),
      );

      if (!mounted) return;
      final otpVerified = await _showOtpDialog();
      if (otpVerified && mounted) {
        Navigator.of(context).pop();
        _showModalNotificationGlobal(
          context,
          'Registration successful. You can now log in to your account.',
          bgColor: ParishColors.greenSuccess,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Signup OTP request error: ${e.code} ${e.message}');
      _showModalNotificationGlobal(
        context,
        '${e.code}: ${e.message ?? 'Unable to send OTP. Please try again.'}',
        bgColor: Colors.red,
      );
    } catch (e) {
      debugPrint('Signup OTP request error: $e');
      _showModalNotificationGlobal(
        context,
        'Unable to send OTP. Please check your network and try again.',
        bgColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 700),
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
              padding: const EdgeInsets.all(24.0),
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
                    widget.isTagalog ? 'Mag-sign up' : 'Sign Up',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isTagalog
                        ? 'Sumali sa ating espirituwal na komunidad'
                        : 'Join our spiritual community',
                    style: TextStyle(fontSize: 14, color: ParishColors.blue200),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      // First Name field
                      TextFormField(
                        controller: firstNameController,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Pangalan'
                              : 'First Name',
                          prefixIcon: Icon(
                            Icons.person,
                            color: ParishColors.primaryGold,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return widget.isTagalog
                                ? 'Pakilagay ang iyong pangalan'
                                : 'Please enter your first name';
                          }
                          if (value.length < 2) {
                            return widget.isTagalog
                                ? 'Dapat ay hindi bababa sa 2 character ang pangalan'
                                : 'First name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Last Name field
                      TextFormField(
                        controller: lastNameController,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Apelyido'
                              : 'Last Name',
                          prefixIcon: Icon(
                            Icons.person_outline,
                            color: ParishColors.primaryGold,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return widget.isTagalog
                                ? 'Pakilagay ang iyong apelyido'
                                : 'Please enter your last name';
                          }
                          if (value.length < 2) {
                            return widget.isTagalog
                                ? 'Dapat ay hindi bababa sa 2 character ang apelyido'
                                : 'Last name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Email field
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Email'
                              : 'Email Address',
                          prefixIcon: Icon(
                            Icons.email,
                            color: ParishColors.primaryGold,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Phone Number field (Philippine format)
                          TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          PhilippinePhoneInputFormatter(),
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Numero ng Telepono'
                              : 'Phone Number',
                          hintText: '09XXXXXXXXX',
                          prefixIcon: Icon(
                            Icons.phone,
                            color: ParishColors.primaryGold,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: _validatePhone,
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        initialValue: selectedBarangay,
                        decoration: InputDecoration(
                          labelText: 'Barangay',
                          prefixIcon: Icon(
                            Icons.map,
                            color: ParishColors.primaryGold,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        items: _barangayOptions
                            .map(
                              (barangay) => DropdownMenuItem(
                                value: barangay,
                                child: Text(barangay),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedBarangay = value;
                            if (value != null && value != 'Others') {
                              addressController.text = 'San Ildefonso, Bulacan';
                              isMunicipalityProvinceReadOnly = true;
                            } else {
                              if (value == 'Others') {
                                addressController.clear();
                              }
                              isMunicipalityProvinceReadOnly = false;
                            }
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return widget.isTagalog
                                ? 'Piliin ang barangay'
                                : 'Please select barangay';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: addressController,
                        readOnly: isMunicipalityProvinceReadOnly,
                        decoration: InputDecoration(
                          labelText: 'Municipality and Province',
                          hintText: 'Enter municipality and province',
                          prefixIcon: Icon(
                            Icons.location_city,
                            color: ParishColors.primaryGold,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return widget.isTagalog
                                ? 'Pakilagay ang munisipyo at probinsya'
                                : 'Please enter the municipality and province';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Birthday date picker
                      TextFormField(
                        controller: birthdayController,
                        readOnly: true,
                        onTap: _pickBirthday,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Kaarawan'
                              : 'Birthday',
                          prefixIcon: Icon(
                            Icons.cake,
                            color: ParishColors.primaryGold,
                          ),
                          suffixIcon: const Icon(Icons.calendar_today),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return widget.isTagalog
                                ? 'Piliin ang iyong kaarawan'
                                : 'Please select your birthday';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog ? 'Password' : 'Password',
                          prefixIcon: Icon(
                            Icons.lock,
                            color: ParishColors.primaryGold,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: ParishColors.textGray600,
                            ),
                            onPressed: () {
                              setState(
                                () => obscurePassword = !obscurePassword,
                              );
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Confirm Password field
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Kumpirmahin ang Password'
                              : 'Confirm Password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: ParishColors.primaryGold,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: ParishColors.textGray600,
                            ),
                            onPressed: () {
                              setState(
                                () => obscureConfirmPassword =
                                    !obscureConfirmPassword,
                              );
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Terms and conditions checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: acceptTerms,
                            onChanged: (value) {
                              setState(() => acceptTerms = value ?? false);
                            },
                            activeColor: ParishColors.primaryGold,
                            checkColor: ParishColors.primaryBlue,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => acceptTerms = !acceptTerms);
                              },
                              child: RichText(
                                text: TextSpan(
                                  text: 'I agree to the ',
                                  style: TextStyle(
                                    color: ParishColors.textBlue900,
                                    fontSize: 12,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Terms and Conditions',
                                      style: TextStyle(
                                        color: ParishColors.primaryGold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: TextStyle(
                                        color: ParishColors.primaryGold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Signup button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : handleSignup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.primaryGold,
                            foregroundColor: ParishColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isTagalog ? 'Mag-sign up' : 'Sign Up',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
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

// Forgot Password Modal Dialog
class ForgotPasswordModal extends StatefulWidget {
  final bool isTagalog;

  const ForgotPasswordModal({super.key, this.isTagalog = false});

  @override
  State<ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends State<ForgotPasswordModal> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  Future<void> handleSendOtp() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      debugPrint(
        'Sending password reset OTP to: ${emailController.text.trim()}',
      );

      await FirebaseService.instance.requestPasswordResetOtp(
        email: emailController.text.trim(),
      );
      debugPrint('Password reset OTP sent successfully');

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showOtpVerificationModal();
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Password reset OTP request error: ${e.code} ${e.message}');
      debugPrint('Error details: ${e.details}');

      String errorMessage;
      if (e.code == 'internal') {
        errorMessage = widget.isTagalog
            ? 'Server error. Firebase Functions may not be deployed. Please contact support.'
            : 'Server error. Firebase Functions may not be deployed. Please contact support.';
      } else if (e.code == 'not-found') {
        errorMessage = widget.isTagalog
            ? 'Hindi namin mahanap ang email na ito.'
            : 'Email not found in our system.';
      } else if (e.code == 'unavailable') {
        errorMessage = widget.isTagalog
            ? 'Service unavailable. Please try again later.'
            : 'Service unavailable. Please try again later.';
      } else {
        errorMessage =
            '${e.code}: ${e.message ?? 'Unable to send OTP. Please try again.'}';
      }

      _showModalNotificationGlobal(context, errorMessage, bgColor: Colors.red);
    } catch (e) {
      debugPrint('Password reset OTP request error: $e');
      _showModalNotificationGlobal(
        context,
        widget.isTagalog
            ? 'Hindi maipadala ang OTP. Suriin ang iyong koneksyon at subukan muli.'
            : 'Unable to send OTP. Please check your network and try again.',
        bgColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showOtpVerificationModal() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PasswordResetOtpModal(
          email: emailController.text.trim(),
          isTagalog: widget.isTagalog,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24.0),
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
                      widget.isTagalog
                          ? 'Nakalimutan ang Password'
                          : 'Forgot Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isTagalog
                          ? 'Ilagay ang iyong email upang makakuha ng OTP'
                          : 'Enter your email to receive an OTP',
                      style: TextStyle(
                        fontSize: 14,
                        color: ParishColors.blue200,
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      // Email field
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Email'
                              : 'Email Address',
                          prefixIcon: Icon(
                            Icons.email,
                            color: ParishColors.primaryGold,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return widget.isTagalog
                                ? 'Please enter your email'
                                : 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return widget.isTagalog
                                ? 'Please enter a valid email'
                                : 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Send OTP button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : handleSendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.primaryGold,
                            foregroundColor: ParishColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isTagalog
                                      ? 'Ipadala ang OTP'
                                      : 'Send OTP',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Password Reset OTP Modal Dialog
class PasswordResetOtpModal extends StatefulWidget {
  final String email;
  final bool isTagalog;

  const PasswordResetOtpModal({
    super.key,
    required this.email,
    this.isTagalog = false,
  });

  @override
  State<PasswordResetOtpModal> createState() => _PasswordResetOtpModalState();
}

class _PasswordResetOtpModalState extends State<PasswordResetOtpModal> {
  final formKey = GlobalKey<FormState>();
  final otpController = TextEditingController();
  bool isLoading = false;
  bool isResendingOtp = false;
  String otpErrorMessage = '';

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> handleVerifyOtp() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);
    otpErrorMessage = '';

    try {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showNewPasswordModal(otpController.text.trim());
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        otpErrorMessage = e.message ?? 'OTP verification failed.';
        isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        otpErrorMessage = e.message ?? 'OTP verification failed.';
        isLoading = false;
      });
    } catch (_) {
      setState(() {
        otpErrorMessage = 'OTP verification failed. Please try again.';
        isLoading = false;
      });
    }
  }

  Future<void> handleResendOtp() async {
    setState(() => isResendingOtp = true);
    otpErrorMessage = '';

    try {
      debugPrint('Resending password reset OTP to: ${widget.email}');
      await FirebaseService.instance.requestPasswordResetOtp(
        email: widget.email,
      );
      debugPrint('Password reset OTP resent successfully');

      if (!mounted) return;
      _showModalNotificationGlobal(
        context,
        widget.isTagalog
            ? 'Bagong OTP na ipinadala sa iyong email.'
            : 'A new OTP was sent to your email.',
        bgColor: ParishColors.greenSuccess,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Password reset OTP resend error: ${e.code} ${e.message}');
      debugPrint('Error details: ${e.details}');

      String errorMessage;
      if (e.code == 'internal') {
        errorMessage = widget.isTagalog
            ? 'Server error. Please check your internet connection and try again.'
            : 'Server error. Please check your internet connection and try again.';
      } else if (e.code == 'not-found') {
        errorMessage = widget.isTagalog
            ? 'Hindi namin mahanap ang email na ito.'
            : 'Email not found in our system.';
      } else {
        errorMessage = e.message ?? 'Unable to resend OTP. Please try again.';
      }

      setState(() {
        otpErrorMessage = errorMessage;
      });
    } catch (e) {
      debugPrint('Password reset OTP resend error: $e');
      setState(() {
        otpErrorMessage = widget.isTagalog
            ? 'Hindi maipadala ang OTP. Suriin ang iyong koneksyon at subukan muli.'
            : 'Unable to resend OTP. Please check your network and try again.';
      });
    } finally {
      setState(() => isResendingOtp = false);
    }
  }

  Future<void> _showNewPasswordModal(String otp) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return NewPasswordModal(
          email: widget.email,
          otp: otp,
          isTagalog: widget.isTagalog,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24.0),
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
                      widget.isTagalog ? 'I-verify ang OTP' : 'Verify OTP',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isTagalog
                          ? 'Ilagay ang 6-digit na OTP na ipinadala sa ${widget.email}'
                          : 'Enter the 6-digit OTP sent to ${widget.email}',
                      style: TextStyle(
                        fontSize: 14,
                        color: ParishColors.blue200,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      // OTP field
                      TextFormField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog ? 'OTP Code' : 'OTP Code',
                          prefixIcon: Icon(
                            Icons.security,
                            color: ParishColors.primaryGold,
                          ),
                          counterText: '',
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return widget.isTagalog
                                ? 'Please enter the OTP'
                                : 'Please enter the OTP';
                          }
                          if (value.length != 6) {
                            return widget.isTagalog
                                ? 'OTP must be 6 digits'
                                : 'OTP must be 6 digits';
                          }
                          return null;
                        },
                      ),

                      if (otpErrorMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          otpErrorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Verify button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : handleVerifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.primaryGold,
                            foregroundColor: ParishColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isTagalog ? 'I-verify' : 'Verify',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Resend button
                      TextButton(
                        onPressed: isResendingOtp || isLoading
                            ? null
                            : handleResendOtp,
                        child: isResendingOtp
                            ? Text(
                                widget.isTagalog
                                    ? 'Nagpapadala...'
                                    : 'Sending...',
                                style: TextStyle(
                                  color: ParishColors.primaryGold,
                                  fontSize: 14,
                                ),
                              )
                            : Text(
                                widget.isTagalog
                                    ? 'Ipadala ulit ang OTP'
                                    : 'Resend OTP',
                                style: TextStyle(
                                  color: ParishColors.primaryGold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// New Password Modal Dialog
class NewPasswordModal extends StatefulWidget {
  final String email;
  final String otp;
  final bool isTagalog;

  const NewPasswordModal({
    super.key,
    required this.email,
    required this.otp,
    this.isTagalog = false,
  });

  @override
  State<NewPasswordModal> createState() => _NewPasswordModalState();
}

class _NewPasswordModalState extends State<NewPasswordModal> {
  final formKey = GlobalKey<FormState>();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;
  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> handleResetPassword() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      await FirebaseService.instance.verifyPasswordResetOtpAndResetPassword(
        email: widget.email,
        otp: widget.otp,
        newPassword: newPasswordController.text,
      );

      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).pop(); // Close new password modal

      _showModalNotificationGlobal(
        context,
        widget.isTagalog
            ? 'Matagumpay na na-reset ang iyong password!'
            : 'Your password has been reset successfully!',
        bgColor: ParishColors.greenSuccess,
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Password reset error: ${e.code} ${e.message}');
      _showModalNotificationGlobal(
        context,
        '${e.code}: ${e.message ?? 'Password reset failed. Please try again.'}',
        bgColor: Colors.red,
      );
    } catch (e) {
      debugPrint('Password reset error: $e');
      _showModalNotificationGlobal(
        context,
        'Password reset failed. Please check your network and try again.',
        bgColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24.0),
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
                      widget.isTagalog ? 'Bagong Password' : 'New Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isTagalog
                          ? 'Ilagay ang iyong bagong password'
                          : 'Enter your new password',
                      style: TextStyle(
                        fontSize: 14,
                        color: ParishColors.blue200,
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      // New Password field
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNewPassword,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Bagong Password'
                              : 'New Password',
                          prefixIcon: Icon(
                            Icons.lock,
                            color: ParishColors.primaryGold,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: ParishColors.textGray600,
                            ),
                            onPressed: () {
                              setState(
                                () => obscureNewPassword = !obscureNewPassword,
                              );
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return widget.isTagalog
                                ? 'Please enter your new password'
                                : 'Please enter your new password';
                          }
                          if (value.length < 6) {
                            return widget.isTagalog
                                ? 'Password must be at least 6 characters'
                                : 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      // Confirm Password field
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: widget.isTagalog
                              ? 'Kumpirmahin ang Password'
                              : 'Confirm Password',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: ParishColors.primaryGold,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: ParishColors.textGray600,
                            ),
                            onPressed: () {
                              setState(
                                () => obscureConfirmPassword =
                                    !obscureConfirmPassword,
                              );
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.borderBlue100,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            borderSide: BorderSide(
                              color: ParishColors.primaryGold,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: ParishColors.bgBlue50.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return widget.isTagalog
                                ? 'Please confirm your password'
                                : 'Please confirm your password';
                          }
                          if (value != newPasswordController.text) {
                            return widget.isTagalog
                                ? 'Passwords do not match'
                                : 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // Reset Password button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : handleResetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.primaryGold,
                            foregroundColor: ParishColors.primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isTagalog
                                      ? 'I-reset ang Password'
                                      : 'Reset Password',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Input formatter for Philippine phone numbers
class PhilippinePhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Allow empty value
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    var digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 11 digits (Philippine mobile number)
    if (digitsOnly.length > 11) {
      digitsOnly = digitsOnly.substring(0, 11);
    }

    // Must start with 0
    if (digitsOnly.isNotEmpty && digitsOnly[0] != '0') {
      digitsOnly = '0$digitsOnly';
    }

    // Second digit must be 9 for Philippine mobile
    if (digitsOnly.length > 1 && digitsOnly[1] != '9') {
      // If not 9, keep only the first digit
      digitsOnly = digitsOnly[0];
    }

    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}
