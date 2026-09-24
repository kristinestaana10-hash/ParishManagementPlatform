import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/gradients.dart';
import '../../../core/design/responsive.dart';
import '../../../core/widgets/responsive_modal.dart';
import '../../../core/services/firebase_service.dart';

void _showModalNotificationGlobal(
  BuildContext context,
  String message, {
  Color bgColor = ParishColors.primaryBlue,
}) {
  showResponsiveNotification(
    context: context,
    message: message,
    bgColor: bgColor,
    duration: const Duration(seconds: 2),
  );
}

enum DonationType { monetary, massOffering, inKind, other }

class DonationFeature extends StatefulWidget {
  final bool isTagalog;
  final bool isGuest;

  const DonationFeature({
    super.key,
    this.isTagalog = true,
    this.isGuest = false,
  });

  @override
  State<DonationFeature> createState() => _DonationFeatureState();
}

class _DonationFeatureState extends State<DonationFeature>
    with SingleTickerProviderStateMixin {
  static const _generalMonetaryDonationDescription =
      'This monetary donation is considered a general donation for the parish church and will be used to support its ministries, programs, and ongoing needs. If you wish to contribute to a specific cause, please wait for the official donation drive dedicated to that purpose.';

  DonationType _selectedType = DonationType.monetary;
  bool _isAnonymous = false;
  bool _isLoading = false;
  bool _hasPendingXenditPayment = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _paymentStatusSubscription;
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _itemsController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedOfferingLocation = 'Sto. Rosario Parish';
  final List<String> _offeringLocations = [
    'Pasong Bangkal',
    'Sitio Pag-asa',
    'Pulong Tamo',
    'Sapang Putik',
    'Bagong Silang',
    'Bagong Barrio',
    'Upig',
    'Telapatio',
    'Calawitan',
    'Maasim',
    'Calasag',
    'Sto. Rosario Parish',
  ];

  String t(String tagalog, String english) => isTagalog ? tagalog : english;

  bool get isTagalog => widget.isTagalog;

  @override
  void initState() {
    super.initState();
    // Guest users: 1 tab (Donate)
    // Logged-in users: 2 tabs (Donate, My Donations) - Anonymous removed
    _tabController = TabController(length: widget.isGuest ? 1 : 2, vsync: this);

    // Load user profile data for auto-fill if not guest
    if (!widget.isGuest) {
      _loadUserProfileData();
    }
  }

  Future<void> _loadUserProfileData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Get user data from Firestore
        final userData = await FirebaseService.instance.getCurrentUserData();
        if (userData != null && mounted) {
          setState(() {
            // Pre-fill with Firestore data if available, fallback to Auth data
            _nameController.text =
                userData['name'] as String? ?? currentUser.displayName ?? '';
            _emailController.text =
                userData['email'] as String? ?? currentUser.email ?? '';
            _phoneController.text = userData['phone'] as String? ?? '';
          });
        } else if (mounted) {
          // Fallback to Auth data only
          setState(() {
            _nameController.text = currentUser.displayName ?? '';
            _emailController.text = currentUser.email ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile for donation: $e');
      // Silently fail - user can manually enter info
    }
  }

  @override
  void dispose() {
    _paymentStatusSubscription?.cancel();
    _tabController.dispose();
    _amountController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _itemsController.dispose();
    _descriptionController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String _normalizePhilippinePhone(String rawPhone) {
    final digitsOnly = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';

    var digits = digitsOnly;
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('63')) {
      digits = digits.substring(2);
    }

    return '+63$digits';
  }

  bool _isValidPhilippinePhone(String rawPhone) {
    final normalized = _normalizePhilippinePhone(rawPhone);
    return RegExp(r'^\+639\d{9}$').hasMatch(normalized);
  }

  double? _parsePhpAmount(String value) {
    // Accept display-friendly entries such as "₱1,000" and "1,000.50".
    final normalized = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (normalized.isEmpty || RegExp(r'\..*\.').hasMatch(normalized)) {
      return null;
    }
    return double.tryParse(normalized);
  }

  void _watchVerifiedPayment({
    required String collection,
    required String documentId,
  }) {
    _paymentStatusSubscription?.cancel();
    _paymentStatusSubscription = FirebaseFirestore.instance
        .collection(collection)
        .doc(documentId)
        .snapshots()
        .listen((snapshot) {
          final status = (snapshot.data()?['status'] ?? '')
              .toString()
              .toLowerCase();
          if (status == 'paid') {
            _paymentStatusSubscription?.cancel();
            _paymentStatusSubscription = null;
            if (!mounted) return;
            _clearDonationForm();
            setState(() => _hasPendingXenditPayment = false);
            // The return deep link displays the acknowledgement after the
            // server has independently verified Xendit. Do not display a
            // second success message merely because this listener updated.
          } else if (status == 'failed' || status == 'expired') {
            _paymentStatusSubscription?.cancel();
            _paymentStatusSubscription = null;
            if (!mounted) return;
            setState(() => _hasPendingXenditPayment = false);
            _showModalNotificationGlobal(
              context,
              t(
                'Hindi nakumpleto ang bayad. Nananatiling hindi bayad ang transaksyon.',
                'The payment was not completed. This transaction was not marked as paid.',
              ),
              bgColor: Colors.red,
            );
          }
        });
  }

  void _clearDonationForm() {
    _formKey.currentState?.reset();
    _amountController.clear();
    _nameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _itemsController.clear();
    _descriptionController.clear();
    _messageController.clear();
    setState(() {
      _selectedType = DonationType.monetary;
      _isAnonymous = false;
      _selectedOfferingLocation = 'Sto. Rosario Parish';
    });
  }

  Future<void> _submitDonation() async {
    if (!_formKey.currentState!.validate()) return;

    final phoneRaw = _phoneController.text.trim();
    final phoneFormatted = phoneRaw.isNotEmpty
        ? _normalizePhilippinePhone(phoneRaw)
        : '';

    if (phoneRaw.isNotEmpty && !_isValidPhilippinePhone(phoneRaw)) {
      throw Exception(
        t(
          'Mangyaring maglagay ng wastong Philippine phone number',
          'Please enter a valid Philippine phone number',
        ),
      );
    }

    setState(() => _isLoading = true);

    try {
      // Get current user for Firebase Auth data
      final currentUser = FirebaseAuth.instance.currentUser;

      // Prepare userName and userEmail with proper validation
      String userName;
      String userEmail;

      // All users can choose to be anonymous
      if (_isAnonymous) {
        userName = 'Anonymous';
        userEmail = 'anonymous@example.com';
      } else {
        // Use Firebase Auth data if available, otherwise use form data
        final authenticatedName = currentUser?.displayName?.trim() ?? '';
        final authenticatedEmail = currentUser?.email?.trim() ?? '';
        userName = authenticatedName.isNotEmpty
            ? authenticatedName
            : _nameController.text.trim();
        userEmail = authenticatedEmail.isNotEmpty
            ? authenticatedEmail
            : _emailController.text.trim();
        // Logged-in accounts may not have a display name yet; that must not
        // prevent an otherwise valid payment from being created.
        if (userName.isEmpty && currentUser != null) {
          userName = 'Donor';
        }
      }

      // Frontend validation (skip for anonymous donations)
      if (!_isAnonymous) {
        if (userName.isEmpty) {
          throw Exception('User name is required');
        }
        // A receipt email is optional. Validate it only when one was supplied.
        if (userEmail.isNotEmpty &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(userEmail)) {
          throw Exception('Please provide a valid email address');
        }
      }

      if (_selectedType == DonationType.monetary ||
          _selectedType == DonationType.massOffering) {
        // Monetary donations and mass offerings require amount > 0
        final amountValue = _parsePhpAmount(_amountController.text) ?? 0.0;

        if (amountValue <= 0) {
          throw Exception(
            'Amount must be greater than 0 for monetary donations',
          );
        }

        final donationDescription = _selectedType == DonationType.monetary
            ? _generalMonetaryDonationDescription
            : _descriptionController.text.trim();

        final result = _selectedType == DonationType.massOffering
            ? await FirebaseService.instance.createXenditMassOfferingInvoice(
                amount: amountValue,
                isAnonymous: _isAnonymous,
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                userName: userName,
                userEmail: userEmail,
                donationType: _selectedType.name,
                phone: phoneFormatted,
                items: _itemsController.text.trim(),
                description: donationDescription,
                message: _messageController.text.trim(),
                offeringLocation: _selectedOfferingLocation,
              )
            : await FirebaseService.instance.createXenditDonationInvoice(
                amount: amountValue,
                isAnonymous: _isAnonymous,
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                userName: userName,
                userEmail: userEmail,
                donationType: _selectedType.name,
                phone: phoneFormatted,
                items: _itemsController.text.trim(),
                description: donationDescription,
                message: _messageController.text.trim(),
                offeringLocation: _selectedOfferingLocation,
              );

        final checkoutUrl = (result['checkoutUrl'] ?? '').toString();
        if (checkoutUrl.isEmpty) {
          throw Exception('Missing checkoutUrl');
        }

        final uri = Uri.tryParse(checkoutUrl);
        if (uri == null) {
          throw Exception('Invalid checkoutUrl');
        }

        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          throw Exception('Unable to open payment page');
        }

        final paymentId = (result['donationId'] ?? '').toString();
        if (paymentId.isEmpty) {
          throw Exception('Missing payment reference');
        }
        if (mounted) {
          setState(() => _hasPendingXenditPayment = true);
          _watchVerifiedPayment(
            collection: _selectedType == DonationType.massOffering
                ? 'mass_offerings'
                : 'donations',
            documentId: paymentId,
          );
        }

        if (mounted) {
          _showModalNotificationGlobal(
            context,
            t(
              'Bubukas ang payment page. Kapag tapos na, hihintayin ng system ang kumpirmasyon ng bayad. Salamat!',
              'Payment is pending. After Xendit verifies it, the system will confirm your donation.',
            ),
            bgColor: ParishColors.primaryBlue,
          );
        }
      } else if (_selectedType == DonationType.inKind) {
        // In-kind donations require itemName and quantity
        final itemName = _itemsController.text.trim();
        final description = _descriptionController.text.trim();

        if (itemName.isEmpty) {
          throw Exception('Item name is required for in-kind donations');
        }
        if (description.isEmpty) {
          throw Exception(
            'Description/quantity is required for in-kind donations',
          );
        }

        // Use direct Firestore submission to bypass Cloud Function validation
        final donationData = <String, dynamic>{
          'donationType': _selectedType.name,
          'isAnonymous': _isAnonymous,
          'name': _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : userName,
          'email': _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : userEmail,
          'userName': userName,
          'userEmail': userEmail,
          'phone': phoneFormatted,
          'items': itemName,
          'description': description,
          'message': _messageController.text.trim(),
        };

        await FirebaseService.instance.submitDonation(donationData);
      } else if (_selectedType == DonationType.other) {
        // Other donations require description
        final description = _descriptionController.text.trim();

        if (description.isEmpty) {
          throw Exception('Description is required for other types of support');
        }

        // Use direct Firestore submission to bypass Cloud Function validation
        final donationData = <String, dynamic>{
          'donationType': _selectedType.name,
          'isAnonymous': _isAnonymous,
          'name': _nameController.text.trim().isNotEmpty
              ? _nameController.text.trim()
              : userName,
          'email': _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : userEmail,
          'userName': userName,
          'userEmail': userEmail,
          'phone': phoneFormatted,
          'description': description,
          'message': _messageController.text.trim(),
        };

        await FirebaseService.instance.submitDonation(donationData);
      }

      // Xendit payments remain pending until their webhook-confirmed status is
      // received above. Non-payment commitments can be acknowledged now.
      if (mounted &&
          _selectedType != DonationType.monetary &&
          _selectedType != DonationType.massOffering) {
        _showModalNotificationGlobal(
          context,
          t('Salamat sa inyong donasyon!', 'Thank you for your giving!'),
          bgColor: ParishColors.greenSuccess,
        );
        _clearDonationForm();
      }
    } catch (e) {
      if (mounted) {
        var errorMessage = t(
          'Hindi maiproseso ang donasyon. Pakisubukang muli.',
          'Unable to submit the donation. Please try again.',
        );

        if (e is FirebaseFunctionsException) {
          final details = e.details?.toString() ?? '';
          errorMessage = '${e.code}: ${e.message ?? ''} $details'.trim();
        } else {
          errorMessage = e.toString();
        }

        _showModalNotificationGlobal(
          context,
          errorMessage,
          bgColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);

    return Scaffold(
      appBar: widget.isGuest
          ? null
          : AppBar(
              backgroundColor: ParishColors.primaryBlue,
              elevation: 0,
              title: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.transparent,
                        indicator: const BoxDecoration(),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white60,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                        tabs: [
                          Tab(
                            child: Text(
                              t('Donate', 'Give'),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Only show My Donations tab for logged-in users (anonymous removed)
                          if (!widget.isGuest) ...[
                            Tab(
                              child: Text(
                                t('Aking Donasyon', 'My Giving'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Donate Tab
          CustomScrollView(
            slivers: [
              // Header
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                elevation: 0,
                automaticallyImplyLeading: !widget.isGuest,
                leading: const SizedBox.shrink(),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: ParishGradients.blueHeroGradient,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                            border: Border.all(
                              color: ParishColors.primaryGold,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          t('Mga Donasyon', 'Giving'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t('Tumulong sa ating Parokya', 'Help Our Parish'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: ParishColors.blue200,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              SliverToBoxAdapter(
                child: ParishResponsiveScaffold(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // Donation Type Selection
                        Text(
                          t('Uri ng Donasyon', 'Types of Giving'),
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: ParishColors.textBlue900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDonationTypeSelector(isMobile),
                        const SizedBox(height: 24),

                        // Anonymous Toggle - show for all users
                        _buildAnonymousToggle(isMobile),
                        const SizedBox(height: 24),

                        // Dynamic Form Fields Based on Type
                        _buildDonationFormFields(isMobile),
                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading || _hasPendingXenditPayment
                                ? null
                                : _submitDonation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ParishColors.primaryGold,
                              foregroundColor: ParishColors.primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      ParishColors.primaryBlue,
                                    ),
                                  )
                                : Text(
                                    t('Magpadala ng Donasyon', 'Submit'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Info Message
                        _buildInfoMessage(isMobile),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // My Donation Tab is only for logged-in users (anonymous removed)
          if (!widget.isGuest) ...[_buildMyDonationTab(isMobile)],
        ],
      ),
    );
  }

  Widget _buildDonationTypeSelector(bool isMobile) {
    return Column(
      children: [
        _buildTypeButton(
          type: DonationType.monetary,
          label: t('Pera', 'Monetary'),
          icon: Icons.attach_money,
          description: t('Donasyon sa pera', 'Cash giving'),
          isMobile: isMobile,
        ),
        const SizedBox(height: 12),
        _buildTypeButton(
          type: DonationType.massOffering,
          label: t('Handog sa Misa', 'Mass Offering'),
          icon: Icons.church,
          description: t('Handog para sa Misa', 'Offering for Mass'),
          isMobile: isMobile,
        ),
      ],
    );
  }

  Widget _buildTypeButton({
    required DonationType type,
    required String label,
    required IconData icon,
    required String description,
    required bool isMobile,
  }) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? ParishColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? ParishColors.primaryBlue
                : ParishColors.borderBlue100,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? ParishColors.primaryGold
                    : ParishColors.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? ParishColors.primaryBlue
                    : ParishColors.primaryGold,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : ParishColors.textBlue900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: isSelected
                          ? Colors.white70
                          : ParishColors.textGray700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyDonationTab(bool isMobile) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return CustomScrollView(
      slivers: [
        // Header
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          elevation: 0,
          automaticallyImplyLeading: !widget.isGuest,
          leading: const SizedBox.shrink(),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: ParishGradients.blueHeroGradient,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      border: Border.all(
                        color: ParishColors.primaryGold,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.history,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('Aking Donasyon', 'My Giving'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('Kasaysayan ng Donasyon', 'Giving History'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      color: ParishColors.blue200,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Content
        SliverToBoxAdapter(
          child: ParishResponsiveScaffold(
            child: currentUser == null
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ParishColors.bgBlue50,
                              border: Border.all(
                                color: ParishColors.borderBlue100,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.login,
                              color: ParishColors.textGray700,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            t(
                              'Mag-login para makita ang donasyon',
                              'Login to view giving',
                            ),
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.w600,
                              color: ParishColors.textBlue900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : StreamBuilder<
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  >(
                    stream: FirebaseFirestore.instance
                        .collection('donations')
                        .where('userId', isEqualTo: currentUser.uid)
                        .snapshots()
                        .asyncMap((userIdSnapshot) async {
                          // Also fetch donations by email or userEmail for this user,
                          // including anonymous donations associated with their address.
                          final userEmail = currentUser.email ?? '';

                          final emailQuery = await FirebaseFirestore.instance
                              .collection('donations')
                              .where('email', isEqualTo: userEmail)
                              .get();
                          final userEmailQuery = await FirebaseFirestore
                              .instance
                              .collection('donations')
                              .where('userEmail', isEqualTo: userEmail)
                              .get();

                          final massOfferingUserIdQuery =
                              await FirebaseFirestore.instance
                                  .collection('mass_offerings')
                                  .where('userId', isEqualTo: currentUser.uid)
                                  .get();
                          final massOfferingUserEmailQuery =
                              await FirebaseFirestore.instance
                                  .collection('mass_offerings')
                                  .where('userEmail', isEqualTo: userEmail)
                                  .get();
                          final massOfferingEmailQuery = await FirebaseFirestore
                              .instance
                              .collection('mass_offerings')
                              .where('email', isEqualTo: userEmail)
                              .get();

                          // Merge all results and remove duplicates
                          final allDocs =
                              <
                                String,
                                QueryDocumentSnapshot<Map<String, dynamic>>
                              >{};
                          for (final doc in userIdSnapshot.docs) {
                            allDocs[doc.id] = doc;
                          }
                          for (final doc in emailQuery.docs) {
                            allDocs[doc.id] = doc;
                          }
                          for (final doc in userEmailQuery.docs) {
                            allDocs[doc.id] = doc;
                          }
                          for (final doc in massOfferingUserIdQuery.docs) {
                            allDocs[doc.id] = doc;
                          }
                          for (final doc in massOfferingUserEmailQuery.docs) {
                            allDocs[doc.id] = doc;
                          }
                          for (final doc in massOfferingEmailQuery.docs) {
                            allDocs[doc.id] = doc;
                          }

                          return allDocs.values.toList();
                        }),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  t(
                                    'Error loading donations',
                                    'Error loading giving',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  snapshot.error.toString(),
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final donations = snapshot.data ?? [];

                      // Client-side sorting by submittedAt descending
                      donations.sort((a, b) {
                        final aData = a.data();
                        final bData = b.data();
                        final aTime = _parseTimestamp(aData['submittedAt']);
                        final bTime = _parseTimestamp(bData['submittedAt']);
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });

                      if (donations.isEmpty) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: ParishColors.bgBlue50,
                                    border: Border.all(
                                      color: ParishColors.borderBlue100,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.history,
                                    color: ParishColors.textGray700,
                                    size: 48,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  t('Walang donasyon pa', 'No giving yet'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 18 : 20,
                                    fontWeight: FontWeight.w600,
                                    color: ParishColors.textBlue900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          // Debug count
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Found ${donations.length} giving(s)',
                              style: TextStyle(
                                fontSize: isMobile ? 14 : 16,
                                color: ParishColors.textGray600,
                              ),
                            ),
                          ),
                          ...donations.map((doc) {
                            final donation = doc.data();
                            final submittedAt = _parseTimestamp(donation['submittedAt']);
                            final amount =
                                (donation['amount'] as num?)?.toDouble() ?? 0.0;
                            final donationType =
                                donation['donationType'] as String? ??
                                'unknown';
                            final isAnonymous =
                                donation['isAnonymous'] as bool? ?? false;
                            final donorName = isAnonymous
                                ? t('Anonymous', 'Anonymous')
                                : _firstFilledDonationValue(donation, [
                                    'name',
                                    'userName',
                                    'userEmail',
                                    'email',
                                  ]);
                            final displayDonorName = donorName.isNotEmpty
                                ? donorName
                                : t('Unknown', 'Unknown');
                            final accentColor = isAnonymous
                                ? ParishColors.primaryGold
                                : ParishColors.primaryBlue;
                            final donorNameColor = isAnonymous
                                ? Colors.black
                                : accentColor;
                            final amountColor = isAnonymous
                                ? Colors.black
                                : accentColor;
                            final hasAmount = amount > 0;
                            final rightLabel = hasAmount
                                ? 'PHP ${amount.toStringAsFixed(2)}'
                                : _formatDonationType(donationType);
                            final rightLabelColor = hasAmount
                                ? amountColor
                                : ParishColors.textBlue900;
                            final cardBorderColor = isAnonymous
                                ? ParishColors.primaryGold
                                : ParishColors.borderBlue100;
                            final cardBackground = Colors.white;

                            return GestureDetector(
                              onTap: () => _showDonationDetailModal(
                                context,
                                donation,
                                doc.id,
                                isMobile,
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: cardBorderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayDonorName,
                                                style: TextStyle(
                                                  fontSize: isMobile ? 16 : 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: donorNameColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatDonationType(
                                                  donationType,
                                                ),
                                                style: TextStyle(
                                                  fontSize: isMobile ? 12 : 14,
                                                  color:
                                                      ParishColors.textGray700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                rightLabel,
                                                style: TextStyle(
                                                  fontSize: isMobile
                                                      ? (hasAmount ? 18 : 16)
                                                      : (hasAmount ? 20 : 18),
                                                  fontWeight: hasAmount
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  color: rightLabelColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatTimestamp(submittedAt),
                                                style: TextStyle(
                                                  fontSize: isMobile ? 12 : 13,
                                                  color:
                                                      ParishColors.textGray600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (donation['message'] != null &&
                                        donation['message']
                                            .toString()
                                            .isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: ParishColors.primaryGold
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t('Mensahe', 'Message'),
                                              style: TextStyle(
                                                fontSize: isMobile ? 12 : 14,
                                                fontWeight: FontWeight.w600,
                                                color: ParishColors.textBlue900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              donation['message'].toString(),
                                              style: TextStyle(
                                                fontSize: isMobile ? 12 : 13,
                                                color: ParishColors.textGray700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String _formatDonationType(String donationType) {
    switch (donationType) {
      case 'monetary':
        return t('Pera', 'Monetary');
      case 'massOffering':
        return t('Handog sa Misa', 'Mass Offering');
      case 'inKind':
        return t('Mga Bagay', 'In-Kind');
      case 'other':
        return t('Iba', 'Other');
      default:
        return donationType;
    }
  }

  String _firstFilledDonationValue(
    Map<String, dynamic> donation,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = donation[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String _formatTimestamp(dynamic timestamp) {
    final parsedTimestamp = _parseTimestamp(timestamp);
    if (parsedTimestamp == null) return '';
    final date = parsedTimestamp.toDate();
    return '${date.month}/${date.day}/${date.year}';
  }

  Timestamp? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String) {
      try {
        return Timestamp.fromDate(DateTime.parse(value));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Widget _buildAnonymousToggle(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParishColors.borderBlue100, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Anonymous', 'Anonymous'),
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: ParishColors.textBlue900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t(
                    'Manatiling pribado ang inyong impormasyon',
                    'Keep your information private',
                  ),
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: ParishColors.textGray700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            onChanged: (value) => setState(() => _isAnonymous = value),
            activeThumbColor: ParishColors.primaryGold,
            inactiveThumbColor: ParishColors.textGray600,
          ),
        ],
      ),
    );
  }

  Widget _buildDonationFormFields(bool isMobile) {
    if (_selectedType == DonationType.monetary ||
        _selectedType == DonationType.massOffering) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedType == DonationType.massOffering) ...[
            Text(
              t('Pumili ng Lokasyon ng Handog', 'Select Offering Location'),
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: ParishColors.textBlue900,
              ),
            ),
            const SizedBox(height: 12),
            _buildOfferingLocationDropdown(isMobile),
            const SizedBox(height: 16),
          ],
          Text(
            t('Halaga ng Donasyon', 'Amount'),
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: ParishColors.textBlue900,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _amountController,
            labelText: t('Pera (PHP)', 'Amount (PHP)'),
            hintText: '100.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icons.attach_money,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.₱\s]')),
            ],
            validator: (value) {
              // Only validate amount for monetary donations and mass offerings
              if (_selectedType == DonationType.monetary ||
                  _selectedType == DonationType.massOffering) {
                if (value == null || value.isEmpty) {
                  return t('Ipasok ang halaga', 'Please enter amount');
                }

                final amount = _parsePhpAmount(value);
                if (amount == null || amount <= 0) {
                  return t(
                    'Ipasok ang wastong halaga',
                    'Please enter a valid amount',
                  );
                }
              }
              return null;
            },
            isMobile: isMobile,
          ),
          const SizedBox(height: 16),
          if (_selectedType == DonationType.monetary) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ParishColors.primaryBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ParishColors.borderBlue100),
              ),
              child: Text(
                'This monetary donation is considered a general donation for the parish church and will be used to support its ministries, programs, and ongoing needs. If you wish to contribute to a specific cause, please wait for the official donation drive dedicated to that purpose.',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  height: 1.45,
                  color: ParishColors.textGray700,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildPersonalInfoFields(isMobile),
        ],
      );
    } else if (_selectedType == DonationType.inKind) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Mga Detalye ng Donasyon', 'Giving Details'),
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: ParishColors.textBlue900,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _itemsController,
            labelText: t('Anong uri ng mga bagay?', 'What items?'),
            hintText: t(
              'bitbit...pagkain, damit, etc',
              'list...food, clothes, etc',
            ),
            maxLines: 3,
            prefixIcon: Icons.card_giftcard,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return t('Samantalahin ang detalye', 'Please provide details');
              }
              return null;
            },
            isMobile: isMobile,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _descriptionController,
            labelText: t('Karagdagang Impormasyon', 'Additional Details'),
            hintText: t('Deskribisyon...', 'Description...'),
            maxLines: 3,
            prefixIcon: Icons.description,
            validator: (value) {
              if (_selectedType == DonationType.inKind) {
                if (value == null || value.isEmpty) {
                  return t('Magbigay ng detalye', 'Please provide details');
                }
              }
              return null;
            },
            isMobile: isMobile,
          ),
          const SizedBox(height: 16),
          _buildPersonalInfoFields(isMobile),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Anong Suporta ang Aming Kailangan?', 'Type of Support'),
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: ParishColors.textBlue900,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _descriptionController,
            labelText: t('Paglalarawan', 'Description'),
            hintText: t(
              'Volontaryo na gawain, teknikal na tulong, atbp...',
              'Volunteer work, technical help, etc...',
            ),
            maxLines: 4,
            prefixIcon: Icons.volunteer_activism,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return t('Magbigay ng detalye', 'Please provide details');
              }
              return null;
            },
            isMobile: isMobile,
          ),
          const SizedBox(height: 16),
          _buildPersonalInfoFields(isMobile),
        ],
      );
    }
  }

  Widget _buildOfferingLocationDropdown(bool isMobile) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedOfferingLocation,
      style: TextStyle(
        color: ParishColors.textBlue900,
        fontSize: isMobile ? 14 : 15,
        fontWeight: FontWeight.w600,
      ),
      dropdownColor: Colors.white,
      decoration: InputDecoration(
        labelText: t('Piliin ang Kapilya o Parokya', 'Choose chapel or parish'),
        prefixIcon: const Icon(
          Icons.location_on,
          color: ParishColors.primaryBlue,
        ),
        suffixIcon: const Icon(
          Icons.arrow_drop_down,
          color: ParishColors.primaryBlue,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(color: ParishColors.borderBlue100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(color: ParishColors.borderBlue100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.0),
          borderSide: BorderSide(color: ParishColors.primaryBlue, width: 2),
        ),
        filled: true,
        fillColor: ParishColors.bgBlue50.withValues(alpha: 0.35),
      ),
      items: _offeringLocations
          .map(
            (location) => DropdownMenuItem(
              value: location,
              child: Text(
                location,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedOfferingLocation = value);
        }
      },
      menuMaxHeight: 300,
    );
  }

  Widget _buildPersonalInfoFields(bool isMobile) {
    // For all users, show fields based on anonymous toggle
    if (_isAnonymous) {
      // Anonymous donation - show optional email field for receipt
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ParishColors.primaryGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ParishColors.primaryGold.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info,
                  color: ParishColors.primaryGold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t(
                      'Ang inyong impormasyon ay protektado. Maaari mong ilagay ang iyong email upang matanggap ang resibo (opsyonal).',
                      'Your information is protected. You may enter your email to receive a receipt (optional).',
                    ),
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: ParishColors.textGray700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _emailController,
            labelText: t('Email (Opsyonal)', 'Email (Optional)'),
            hintText: t(
              'Ilagay kung nais mong matanggap ang resibo',
              'Enter if you want to receive a receipt',
            ),
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email,
            validator: (value) {
              final trimmed = (value ?? '').trim();
              // Email is optional for anonymous donations
              if (trimmed.isEmpty) {
                return null; // Allow empty
              }
              // Validate if provided
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
                return t(
                  'Ipasok ang wastong email',
                  'Please enter a valid email',
                );
              }
              return null;
            },
            isMobile: isMobile,
          ),
        ],
      );
    } else if (widget.isGuest) {
      // Non-anonymous guest donations still need personal info input
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Inyong Impormasyon', 'Your Information'),
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: ParishColors.textBlue900,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _nameController,
            labelText: t('Buong Pangalan', 'Full Name'),
            hintText: widget.isGuest
                ? t(
                    'Kinakailangan para sa hindi anon na donasyon',
                    'Required for non-anonymous donation',
                  )
                : '',
            prefixIcon: Icons.person,
            validator: (value) {
              // Name is required for guest non-anonymous donations
              if (widget.isGuest && (value == null || value.isEmpty)) {
                return t('Ipasok ang pangalan', 'Please enter name');
              }
              return null;
            },
            isMobile: isMobile,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _emailController,
            labelText: t('Email (Opsyonal)', 'Email Address (Optional)'),
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email,
            validator: (value) {
              final trimmed = (value ?? '').trim();
              if (trimmed.isNotEmpty &&
                  !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
                return t(
                  'Ipasok ang wastong email',
                  'Please enter a valid email',
                );
              }
              return null;
            },
            isMobile: isMobile,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _phoneController,
            labelText: t('Numero ng Telepono', 'Phone Number'),
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone,
            inputFormatters: widget.isGuest
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ]
                : [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
            validator: (value) {
              final raw = (value ?? '').trim();
              if (raw.isEmpty) return null;

              if (widget.isGuest) {
                // Guests must enter exactly 11 digits (local Philippine format: 09XXXXXXXXX)
                if (raw.length != 11 || !RegExp(r'^09\d{9}$').hasMatch(raw)) {
                  return t(
                    'Mangyaring maglagay ng 11-digit na Philippine phone (09XXXXXXXXX)',
                    'Please enter an 11-digit Philippine phone (09XXXXXXXXX)',
                  );
                }
                return null;
              }

              if (!_isValidPhilippinePhone(raw)) {
                return t(
                  'Mangyaring maglagay ng wastong Philippine phone number',
                  'Please enter a valid Philippine phone number',
                );
              }
              return null;
            },
            isMobile: isMobile,
          ),
        ],
      );
    }

    // Logged-in non-anonymous donors do not need to see the personal info section.
    return const SizedBox.shrink();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    String? hintText,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    required bool isMobile,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        prefixIconColor: ParishColors.primaryGold,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: ParishColors.borderBlue100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: ParishColors.primaryGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        filled: true,
        fillColor: ParishColors.bgBlue50.withValues(alpha: 0.3),
      ),
      inputFormatters: inputFormatters,
      validator: validator,
    );
  }

  Widget _buildInfoMessage(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ParishColors.primaryBlue.withValues(alpha: 0.1),
            ParishColors.primaryBlue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ParishColors.primaryBlue.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ParishColors.primaryBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.help, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  t('Kailangan ng Tulong?', 'Need Help?'),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textBlue900,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: ParishColors.textGray600,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            t(
              'Makipag-ugnayan sa amin para sa anumang katanungan tungkol sa inyong donasyon.',
              'Contact us for any questions about your giving.',
            ),
            style: TextStyle(
              fontSize: isMobile ? 14 : 15,
              height: 1.8,
              color: ParishColors.textGray700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnonymousDonationsTab(bool isMobile) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          elevation: 0,
          automaticallyImplyLeading: !widget.isGuest,
          leading: const SizedBox.shrink(),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: ParishGradients.blueHeroGradient,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      border: Border.all(
                        color: ParishColors.primaryGold,
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.visibility_off,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('Anonymous Donations', 'Anonymous'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('Mga Pribadong Donasyon', 'Private Contributions'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      color: ParishColors.blue200,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Content
        SliverToBoxAdapter(
          child: ParishResponsiveScaffold(
            child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('isAnonymous', isEqualTo: true)
                  .snapshots()
                  .asyncMap((snapshot) async {
                    // Filter out duplicates and sort
                    final allDocs =
                        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
                    for (final doc in snapshot.docs) {
                      allDocs[doc.id] = doc;
                    }
                    return allDocs.values.toList();
                  }),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            t(
                              'Error loading donations',
                              'Error loading giving',
                            ),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final donations = snapshot.data ?? [];

                // Client-side sorting by submittedAt descending
                donations.sort((a, b) {
                  final aData = a.data();
                  final bData = b.data();
                  final aTime = _parseTimestamp(aData['submittedAt']);
                  final bTime = _parseTimestamp(bData['submittedAt']);
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                if (donations.isEmpty) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ParishColors.bgBlue50,
                              border: Border.all(
                                color: ParishColors.borderBlue100,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.visibility_off,
                              color: ParishColors.textGray700,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            t(
                              'Walang anonymous donasyon pa',
                              'No anonymous giving yet',
                            ),
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.w600,
                              color: ParishColors.textBlue900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t(
                              'Ang mga anonymous na donasyon ay magpapakita dito',
                              'Anonymous giving will appear here',
                            ),
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: ParishColors.textGray600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // Count
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Found ${donations.length} anonymous giving(s)',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: ParishColors.textGray600,
                        ),
                      ),
                    ),
                    ...donations.map((doc) {
                      final donation = doc.data();
                      final submittedAt = _parseTimestamp(donation['submittedAt']);
                      final amount =
                          (donation['amount'] as num?)?.toDouble() ?? 0.0;
                      final donationType =
                          donation['donationType'] as String? ?? 'unknown';

                      return GestureDetector(
                        onTap: () => _showDonationDetailModal(
                          context,
                          donation,
                          doc.id,
                          isMobile,
                        ),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ParishColors.borderBlue100,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ParishColors.primaryGold
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.visibility_off,
                                      color: ParishColors.primaryGold,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t(
                                            'Anonymous Donor',
                                            'Anonymous Donor',
                                          ),
                                          style: TextStyle(
                                            fontSize: isMobile ? 16 : 18,
                                            fontWeight: FontWeight.bold,
                                            color: ParishColors.textBlue900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          donationType,
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 14,
                                            color: ParishColors.textGray700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ParishColors.bgBlue50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        if (amount > 0)
                                          Text(
                                            'PHP ${amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: isMobile ? 18 : 20,
                                              fontWeight: FontWeight.bold,
                                              color: ParishColors.primaryBlue,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatTimestamp(submittedAt),
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 13,
                                            color: ParishColors.textGray600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (donation['message'] != null &&
                                  donation['message'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ParishColors.primaryGold
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t('Mensahe', 'Message'),
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 14,
                                            fontWeight: FontWeight.w600,
                                            color: ParishColors.textBlue900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          donation['message'].toString(),
                                          style: TextStyle(
                                            fontSize: isMobile ? 12 : 13,
                                            color: ParishColors.textGray700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showDonationDetailModal(
    BuildContext context,
    Map<String, dynamic> donation,
    String docId,
    bool isMobile,
  ) {
    final isAnonymous = donation['isAnonymous'] as bool? ?? false;
    final donorName = isAnonymous
        ? t('Anonymous Donor', 'Anonymous Donor')
        : (_firstFilledDonationValue(donation, [
                'name',
                'userName',
                'userEmail',
                'email',
              ]).isNotEmpty
              ? _firstFilledDonationValue(donation, [
                  'name',
                  'userName',
                  'userEmail',
                  'email',
                ])
              : t('Unknown', 'Unknown'));
    final donationType = donation['donationType'] as String? ?? 'unknown';
    final amount = (donation['amount'] as num?)?.toDouble() ?? 0.0;
    final submittedAt = _parseTimestamp(donation['submittedAt']);
    final status = donation['status'] as String? ?? 'pending';
    final message = donation['message'] as String? ?? '';
    final email =
        _firstFilledDonationValue(donation, ['email', 'userEmail']);
    final phone = donation['phone'] as String? ?? '';
    final items = donation['items'] as String? ?? '';
    final description = donation['description'] as String? ?? '';
    final donationUpdates =
        donation['parishionerUpdates'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: ParishGradients.blueHeroGradient,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isAnonymous ? Icons.visibility_off : Icons.person,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('Detalye ng Donasyon', 'Giving Details'),
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    color: ParishColors.blue200,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  donorName,
                                  style: TextStyle(
                                    fontSize: isMobile ? 18 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'completed'
                                ? Colors.green.withValues(alpha: 0.1)
                                : status == 'pending'
                                ? ParishColors.primaryGold.withValues(
                                    alpha: 0.1,
                                  )
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: status == 'completed'
                                  ? Colors.green
                                  : status == 'pending'
                                  ? ParishColors.primaryGold
                                  : Colors.red,
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: status == 'completed'
                                  ? Colors.green
                                  : status == 'pending'
                                  ? ParishColors.primaryGold
                                  : Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Amount (for monetary)
                        if (amount > 0)
                          _buildDetailRow(
                            isMobile,
                            Icons.attach_money,
                            t('Halaga', 'Amount'),
                            'PHP ${amount.toStringAsFixed(2)}',
                            isAmount: true,
                          ),
                        // Donation Type
                        _buildDetailRow(
                          isMobile,
                          Icons.card_giftcard,
                          t('Uri ng Donasyon', 'Giving Type'),
                          donationType,
                        ),
                        // Date
                        _buildDetailRow(
                          isMobile,
                          Icons.calendar_today,
                          t('Petsa', 'Date'),
                          _formatTimestamp(submittedAt),
                        ),
                        // Reference ID
                        _buildDetailRow(
                          isMobile,
                          Icons.confirmation_number,
                          t('Reference ID', 'Reference ID'),
                          docId.substring(
                            0,
                            docId.length > 8 ? 8 : docId.length,
                          ),
                        ),
                        const Divider(height: 32),
                        // Contact Info (only for non-anonymous)
                        if (!isAnonymous) ...[
                          Text(
                            t('Impormasyon ng Donor', 'Donor Information'),
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.bold,
                              color: ParishColors.textBlue900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (donorName.isNotEmpty)
                            _buildDetailRow(
                              isMobile,
                              Icons.person,
                              t('Pangalan ng Donor', 'Donor Name'),
                              donorName,
                            ),
                          if (email.isNotEmpty)
                            _buildDetailRow(
                              isMobile,
                              Icons.email,
                              t('Email', 'Email'),
                              email,
                            ),
                          if (phone.isNotEmpty)
                            _buildDetailRow(
                              isMobile,
                              Icons.phone,
                              t('Telepono', 'Phone'),
                              phone,
                            ),
                          const Divider(height: 32),
                        ],
                        // Additional Details
                        if (items.isNotEmpty)
                          _buildDetailRow(
                            isMobile,
                            Icons.inventory_2,
                            t('Mga Item', 'Items'),
                            items,
                          ),
                        if (description.isNotEmpty)
                          _buildDetailRow(
                            isMobile,
                            Icons.description,
                            t('Deskripsyon', 'Description'),
                            description,
                          ),
                        if (message.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: ParishColors.primaryGold.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ParishColors.primaryGold.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.message,
                                      color: ParishColors.primaryGold,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      t('Mensahe', 'Message'),
                                      style: TextStyle(
                                        fontSize: isMobile ? 14 : 16,
                                        fontWeight: FontWeight.bold,
                                        color: ParishColors.textBlue900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 15,
                                    color: ParishColors.textGray700,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (donationType != 'massOffering' &&
                            (description.isNotEmpty ||
                                donationUpdates.isNotEmpty)) ...[
                          const SizedBox(height: 20),
                          // Parishioner Updates Section (Admin Feedback)
                          _buildParishionerUpdatesSection(
                            isMobile,
                            donationUpdates,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Close Button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ParishColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        t('Isara', 'Close'),
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ), // Container
        ); // Dialog
      },
    );
  }

  Widget _buildParishionerUpdatesSection(bool isMobile, List<dynamic> updates) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ParishColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ParishColors.primaryBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.admin_panel_settings,
                color: ParishColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                t('Donation Update', 'Giving Update'),
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: ParishColors.textBlue900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (updates.isEmpty)
            Text(
              t('Wala pang feedback mula sa admin.', 'No admin feedback yet.'),
              style: TextStyle(
                fontSize: isMobile ? 14 : 15,
                color: ParishColors.textGray600,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: updates.map<Widget>((update) {
                if (update is! Map<String, dynamic>) {
                  return const SizedBox.shrink();
                }

                final adminName = 'Sto. Rosario Parish Church';
                final message = update['message'] as String? ?? '';
                final createdAt = update['createdAt'] as String? ?? '';

                // Parse the timestamp string if available
                String formattedDate = '';
                if (createdAt.isNotEmpty) {
                  try {
                    final dateTime = DateTime.parse(createdAt);
                    formattedDate =
                        '${dateTime.month}/${dateTime.day}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                  } catch (e) {
                    formattedDate = createdAt;
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ParishColors.primaryBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            adminName,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              color: ParishColors.primaryBlue,
                            ),
                          ),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              color: ParishColors.textGray600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: ParishColors.textGray700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    bool isMobile,
    IconData icon,
    String label,
    String value, {
    bool isAmount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ParishColors.bgBlue50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: ParishColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: ParishColors.textGray600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile
                        ? (isAmount ? 18 : 14)
                        : (isAmount ? 20 : 16),
                    fontWeight: isAmount ? FontWeight.bold : FontWeight.w600,
                    color: isAmount
                        ? ParishColors.primaryBlue
                        : ParishColors.textBlue900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
