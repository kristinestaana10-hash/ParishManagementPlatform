import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/gradients.dart';
import '../../../core/design/responsive.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/widgets/responsive_modal.dart';

class DonationDrivesScreen extends StatelessWidget {
  final bool isTagalog;
  const DonationDrivesScreen({super.key, this.isTagalog = false});

  String t(String tl, String en) => isTagalog ? tl : en;

  DateTime _createdAt(Map<String, dynamic> drive) {
    final value = drive['createdAt'];
    return value is Timestamp
        ? value.toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);
    return Scaffold(
      backgroundColor: ParishColors.bgBlue50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: ParishColors.primaryBlue,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.maybePop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: ParishGradients.blueHeroGradient,
                ),
                padding: const EdgeInsets.fromLTRB(24, 86, 24, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.volunteer_activism,
                      color: ParishColors.primaryGold,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t('Donation Drives', 'Donation Drives'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 22 : 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t(
                        'Mga aktibong kampanya at proyekto',
                        'Active campaigns and projects',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: ParishColors.blue200),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ParishResponsive.maxContentWidth(context),
                ),
                child: Padding(
                  padding: ParishResponsive.pagePadding(context),
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    // Sorting locally avoids requiring an index and lets older drives without
                    // createdAt remain visible.
                    stream: FirebaseFirestore.instance
                        .collection('donation_drives')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(48),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return _MessageCard(
                          message: t(
                            'Hindi ma-load ang donation drives. Pakisubukan muli.',
                            'Unable to load donation drives. Please try again.',
                          ),
                        );
                      }
                      final drives = (snapshot.data?.docs ?? []).toList()
                        ..sort(
                          (a, b) => _createdAt(
                            b.data(),
                          ).compareTo(_createdAt(a.data())),
                        );
                      if (drives.isEmpty) {
                        return _MessageCard(
                          message: t(
                            'Wala pang donation drive sa ngayon.',
                            'There are no donation drives at this time.',
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final doc in drives)
                            _DriveCard(
                              driveId: doc.id,
                              data: doc.data(),
                              isTagalog: isTagalog,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  const _MessageCard({required this.message});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    ),
  );
}

class _DriveCard extends StatelessWidget {
  final String driveId;
  final Map<String, dynamic> data;
  final bool isTagalog;
  const _DriveCard({
    required this.driveId,
    required this.data,
    required this.isTagalog,
  });
  String t(String tl, String en) => isTagalog ? tl : en;

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? '').toString().trim();
    final description = (data['description'] ?? '').toString().trim();
    final imageUrl = (data['coverImageUrl'] ?? '').toString().trim();
    final target = _firstNumber(data, const [
      'targetAmount',
      'goalAmount',
      'fundingGoal',
      'goal',
    ]);
    final raised = _firstNumber(data, const [
      'raisedAmount',
      'currentAmount',
      'amountRaised',
      'collectedAmount',
    ]);
    final endDate = _firstDate(data, const [
      'endDate',
      'deadline',
      'closingDate',
    ]);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ParishColors.borderBlue100),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DonationDriveDetailScreen(
              driveId: driveId,
              driveData: data,
              isTagalog: isTagalog,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CoverImage(imageUrl: imageUrl, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty
                          ? t('Donation Drive', 'Donation Drive')
                          : title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: ParishColors.textBlue900,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: ParishColors.textGray600),
                      ),
                    ],
                    if (target != null ||
                        raised != null ||
                        endDate != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if (target != null || raised != null)
                            _InfoPill(
                              icon: Icons.savings_outlined,
                              label: _moneyProgress(raised, target),
                            ),
                          if (endDate != null)
                            _InfoPill(
                              icon: Icons.event_outlined,
                              label:
                                  '${t('Hanggang', 'Until')} ${_formatDate(endDate)}',
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      t('Tingnan ang drive', 'View drive'),
                      style: const TextStyle(
                        color: ParishColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: ParishColors.primaryBlue),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: ParishColors.textGray600),
      ),
    ],
  );
}

class _CoverImage extends StatelessWidget {
  final String imageUrl;
  final double size;
  const _CoverImage({required this.imageUrl, required this.size});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageUrl.isEmpty
          ? const ColoredBox(
              color: ParishColors.bgBlue50,
              child: Icon(
                Icons.volunteer_activism,
                color: ParishColors.primaryBlue,
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: ParishColors.bgBlue50,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: ParishColors.textGray500,
                ),
              ),
            ),
    ),
  );
}

enum DriveDonationType { monetary, inKind, other }

class DonationDriveDetailScreen extends StatefulWidget {
  final String driveId;
  final Map<String, dynamic> driveData;
  final bool isTagalog;
  const DonationDriveDetailScreen({
    super.key,
    required this.driveId,
    required this.driveData,
    this.isTagalog = false,
  });
  @override
  State<DonationDriveDetailScreen> createState() =>
      _DonationDriveDetailScreenState();
}

class _DonationDriveDetailScreenState extends State<DonationDriveDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _itemController = TextEditingController();
  final _quantityController = TextEditingController();
  final _conditionController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _otherDetailsController = TextEditingController();
  late final Set<DriveDonationType> _allowedTypes;
  late DriveDonationType _selectedType;
  bool _isAnonymous = false;
  bool _isSubmitting = false;

  String t(String tl, String en) => widget.isTagalog ? tl : en;

  Future<void> _showModalNotification(
    String message, {
    Color bgColor = ParishColors.primaryBlue,
  }) {
    return showResponsiveNotification(
      context: context,
      message: message,
      bgColor: bgColor,
      duration: const Duration(seconds: 2),
    );
  }

  bool get _canSubmit {
    final status = (widget.driveData['status'] ?? 'active')
        .toString()
        .toLowerCase();
    final endDate = widget.driveData['endDate'];
    return const {'active', 'open', 'ongoing', 'published'}.contains(status) &&
        (endDate is! Timestamp || !endDate.toDate().isBefore(DateTime.now()));
  }

  @override
  void initState() {
    super.initState();
    final rawTypes = widget.driveData['allowedDonationTypes'];
    final values = rawTypes is Iterable
        ? rawTypes
              .map(
                (value) => value.toString().toLowerCase().replaceAll(
                  RegExp(r'[^a-z]'),
                  '',
                ),
              )
              .toSet()
        : <String>{};
    _allowedTypes = {
      if (values.isEmpty || values.contains('monetary'))
        DriveDonationType.monetary,
      if (values.isEmpty || values.contains('inkind')) DriveDonationType.inKind,
      if (values.isEmpty ||
          values.contains('othersupport') ||
          values.contains('other'))
        DriveDonationType.other,
    };
    _selectedType = _allowedTypes.first;
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _amountController,
      _nameController,
      _emailController,
      _phoneController,
      _itemController,
      _quantityController,
      _conditionController,
      _deliveryController,
      _otherDetailsController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      _showModalNotification(
        t(
          'Sarado na ang donation drive na ito.',
          'This donation drive is no longer accepting submissions.',
        ),
        bgColor: Colors.red,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final type = _selectedType == DriveDonationType.monetary
          ? 'Monetary'
          : _selectedType == DriveDonationType.inKind
          ? 'In-Kind'
          : 'Other Support';
      final submission = <String, dynamic>{
        'driveId': widget.driveId,
        'driveTitle': widget.driveData['title']?.toString() ?? '',
        'donationType': type,
        'isAnonymous': _isAnonymous,
        'userUid': user?.uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'name': _isAnonymous ? 'Anonymous' : _nameController.text.trim(),
        'email': _isAnonymous ? '' : _emailController.text.trim(),
        'phone': _isAnonymous ? '' : _phoneController.text.trim(),
      };
      if (_selectedType == DriveDonationType.monetary) {
        final amount = double.parse(
          _amountController.text.trim().replaceAll(',', ''),
        );
        final paymentName = _isAnonymous
            ? 'Anonymous'
            : (user?.displayName?.trim().isNotEmpty == true
                  ? user!.displayName!.trim()
                  : _nameController.text.trim());
        final paymentEmail = _isAnonymous
            ? 'anonymous@example.com'
            : (user?.email?.trim().isNotEmpty == true
                  ? user!.email!.trim()
                  : _emailController.text.trim());
        final result = await FirebaseService.instance
            .createXenditDonationInvoice(
              amount: amount,
              isAnonymous: _isAnonymous,
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              userName: paymentName,
              userEmail: paymentEmail,
              phone: _isAnonymous ? '' : _phoneController.text.trim(),
              donationType: 'monetary',
              description: 'Donation drive: ${widget.driveData['title'] ?? ''}',
              paymentReturnType: 'donationDrive',
            );
        final checkoutUrl = (result['checkoutUrl'] ?? '').toString();
        final checkoutUri = Uri.tryParse(checkoutUrl);
        if (checkoutUri == null || checkoutUrl.isEmpty) {
          throw Exception('Missing Xendit checkout URL');
        }
        if (!await launchUrl(
          checkoutUri,
          mode: LaunchMode.externalApplication,
        )) {
          throw Exception('Unable to open Xendit checkout');
        }
        if (!mounted) return;
        _showModalNotification(
          t(
            'Bubukas ang Xendit payment page. Makukumpirma ang donation pagkatapos ng bayad.',
            'Payment is pending. After Xendit verifies it, the system will confirm your donation.',
          ),
        );
        return;
      } else if (_selectedType == DriveDonationType.inKind) {
        submission.addAll({
          'item': _itemController.text.trim(),
          'quantity': _quantityController.text.trim(),
          'condition': _conditionController.text.trim(),
          'deliveryMethod': _deliveryController.text.trim(),
        });
      } else {
        submission['details'] = _otherDetailsController.text.trim();
      }
      await FirebaseFirestore.instance
          .collection('donation_submissions')
          .add(submission);
      if (!mounted) return;
      await _showModalNotification(
        t(
          'Salamat! Natanggap na ang iyong commitment. Makikipag-ugnayan ang parish kung kailangan.',
          'Thank you! Your commitment was received. The parish will contact you if needed.',
        ),
        bgColor: ParishColors.greenSuccess,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      debugPrint('Donation drive submission failed: $error');
      if (mounted) {
        final message = error is FirebaseFunctionsException
            ? (error.message ?? error.code)
            : error.toString().replaceFirst('Exception: ', '');
        _showModalNotification(
          message.isEmpty
              ? t(
                  'Hindi naisumite ang iyong donation. Pakisubukan muli.',
                  'Your donation could not be submitted. Please try again.',
                )
              : message,
          bgColor: Colors.red,
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.driveData['title'] ?? '').toString();
    final description = (widget.driveData['description'] ?? '').toString();
    final imageUrl = (widget.driveData['coverImageUrl'] ?? '').toString();
    final isMobile = ParishBreakpoints.isMobile(context);
    return Scaffold(
      backgroundColor: ParishColors.bgBlue50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            backgroundColor: ParishColors.primaryBlue,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.5),
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: ParishGradients.blueHeroGradient,
                ),
                padding: const EdgeInsets.fromLTRB(24, 70, 24, 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_CoverImage(imageUrl: imageUrl, size: 76)],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ParishResponsive.maxContentWidth(context),
                ),
                child: Padding(
                  padding: ParishResponsive.pagePadding(context),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _CoverImage(
                                  imageUrl: imageUrl,
                                  size: isMobile ? 72 : 104,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: ParishColors.textBlue900,
                                            ),
                                      ),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          description,
                                          style: const TextStyle(
                                            color: ParishColors.textGray600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _DriveDetailsPanel(
                          data: widget.driveData,
                          isTagalog: widget.isTagalog,
                        ),
                        const SizedBox(height: 16),
                        if (!_canSubmit)
                          _MessageCard(
                            message: t(
                              'Sarado na ang donation drive na ito.',
                              'This donation drive is closed.',
                            ),
                          )
                        else ...[
                          Text(
                            t(
                              'Uri ng iyong commitment',
                              'Your commitment type',
                            ),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final type in DriveDonationType.values)
                                if (_allowedTypes.contains(type))
                                  ChoiceChip(
                                    label: Text(_typeLabel(type)),
                                    selected: _selectedType == type,
                                    onSelected: (_) => setState(() {
                                      _selectedType = type;
                                      _isAnonymous = false;
                                    }),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTypeFields(),
                          const SizedBox(height: 8),
                          if (_selectedType == DriveDonationType.monetary)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _isAnonymous,
                              onChanged: (value) =>
                                  setState(() => _isAnonymous = value ?? false),
                              title: Text(
                                t('Manatiling anonymous', 'Donate anonymously'),
                              ),
                            ),
                          if (!_isAnonymous) ...[_contactFields()],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ParishColors.primaryGold,
                                foregroundColor: ParishColors.textBlue900,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      t(
                                        'Isumite ang commitment',
                                        'Submit commitment',
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(DriveDonationType type) => switch (type) {
    DriveDonationType.monetary => t('Pera', 'Monetary'),
    DriveDonationType.inKind => t('In-kind', 'In-kind'),
    DriveDonationType.other => t('Iba pang suporta', 'Other support'),
  };
  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
  Widget _buildTypeFields() {
    if (_selectedType == DriveDonationType.monetary) {
      return _field(
        controller: _amountController,
        label: t('Halaga (₱)', 'Amount (₱)'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        validator: (value) =>
            (double.tryParse((value ?? '').replaceAll(',', '')) ?? 0) > 0
            ? null
            : t('Maglagay ng wastong halaga.', 'Enter a valid amount.'),
      );
    }
    if (_selectedType == DriveDonationType.inKind) {
      return Column(
        children: [
          _field(
            controller: _itemController,
            label: t('Item na ibibigay', 'Item to donate'),
            validator: _required,
          ),
          _field(
            controller: _quantityController,
            label: t('Dami', 'Quantity'),
            validator: _required,
          ),
          _field(
            controller: _conditionController,
            label: t(
              'Kondisyon / karagdagang detalye',
              'Condition / additional details',
            ),
          ),
          _field(
            controller: _deliveryController,
            label: t('Paraan ng paghatid', 'Delivery method'),
          ),
        ],
      );
    }
    return _field(
      controller: _otherDetailsController,
      label: t('Detalye ng suporta', 'Support details'),
      maxLines: 3,
      validator: _required,
    );
  }

  Widget _contactFields() => Column(
    children: [
      _field(
        controller: _nameController,
        label: t('Buong pangalan', 'Full name'),
        validator: _required,
      ),
      _field(
        controller: _emailController,
        label: t('Email address', 'Email address'),
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          final email = value?.trim() ?? '';
          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
              ? null
              : t(
                  'Maglagay ng wastong email address.',
                  'Enter a valid email address.',
                );
        },
      ),
      _field(
        controller: _phoneController,
        label: t('Contact number (opsyonal)', 'Contact number (optional)'),
        keyboardType: TextInputType.phone,
      ),
    ],
  );
  String? _required(String? value) => value == null || value.trim().isEmpty
      ? t('Kinakailangan ang field na ito.', 'This field is required.')
      : null;
}

class _DriveDetailsPanel extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isTagalog;
  const _DriveDetailsPanel({required this.data, required this.isTagalog});

  String t(String tl, String en) => isTagalog ? tl : en;

  @override
  Widget build(BuildContext context) {
    final target = _firstNumber(data, const [
      'targetAmount',
      'goalAmount',
      'fundingGoal',
      'goal',
      'target',
    ]);
    final raised = _firstNumber(data, const [
      'raisedAmount',
      'currentAmount',
      'amountRaised',
      'collectedAmount',
      'totalRaised',
    ]);
    final startDate = _firstDate(data, const [
      'startDate',
      'start',
      'launchDate',
    ]);
    final endDate = _firstDate(data, const [
      'endDate',
      'deadline',
      'closingDate',
    ]);
    final category = _firstText(data, const [
      'category',
      'driveCategory',
      'type',
    ]);
    final beneficiary = _firstText(data, const [
      'beneficiary',
      'beneficiaries',
      'recipient',
      'forWhom',
    ]);
    final location = _firstText(data, const [
      'location',
      'deliveryLocation',
      'dropOffLocation',
    ]);
    final contact = _firstText(data, const [
      'contact',
      'contactPerson',
      'contactNumber',
      'contactEmail',
    ]);
    final instructions = _firstText(data, const [
      'instructions',
      'donationInstructions',
      'howToDonate',
      'notes',
    ]);
    final donationTypes = _firstText(data, const [
      'allowedDonationTypes',
      'donationTypes',
      'acceptedDonationTypes',
    ]);
    final rows = <(String, String)>[
      if (category != null) (t('Kategorya', 'Category'), category),
      if (beneficiary != null) (t('Makikinabang', 'Beneficiary'), beneficiary),
      if (target != null)
        (t('Layunin', 'Fundraising goal'), _moneyProgress(null, target)),
      if (raised != null)
        (t('Nalilikom', 'Amount raised'), _moneyProgress(raised, null)),
      if (startDate != null) (t('Simula', 'Starts'), _formatDate(startDate)),
      if (endDate != null) (t('Hanggang', 'Ends'), _formatDate(endDate)),
      if (location != null) (t('Lugar', 'Location'), location),
      if (contact != null) (t('Makipag-ugnayan', 'Contact'), contact),
      if (donationTypes != null)
        (t('Tinatanggap', 'Accepted donations'), donationTypes),
    ];
    if (rows.isEmpty && instructions == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('Mga detalye ng donation drive', 'Donation drive details'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: ParishColors.textBlue900,
              ),
            ),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.$1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ParishColors.textGray500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.$2,
                      style: const TextStyle(color: ParishColors.textGray700),
                    ),
                  ],
                ),
              ),
            if (instructions != null) ...[
              Text(
                t('Paano tumulong', 'How to help'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ParishColors.textGray500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                instructions,
                style: const TextStyle(color: ParishColors.textGray700),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _firstText(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is List) {
      final result = value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .join(', ');
      if (result.isNotEmpty) return result;
    } else if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return null;
}

num? _firstNumber(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value.replaceAll(',', ''));
      if (parsed != null) return parsed;
    }
  }
  return null;
}

DateTime? _firstDate(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

String _moneyProgress(num? raised, num? target) {
  String money(num value) =>
      '₱${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
  if (raised != null && target != null) {
    return '${money(raised)} / ${money(target)}';
  }
  if (target != null) return '${money(target)} goal';
  return '${money(raised!)} raised';
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

String _displayLabel(String key) => key
    .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    )
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _displayValue(dynamic value) {
  if (value is Timestamp) return _formatDate(value.toDate());
  if (value is DateTime) return _formatDate(value);
  if (value is List) {
    return value
        .map(_displayValue)
        .where((value) => value.isNotEmpty)
        .join(', ');
  }
  if (value is Map) {
    return value.entries
        .map(
          (entry) =>
              '${_displayLabel(entry.key.toString())}: ${_displayValue(entry.value)}',
        )
        .join('\n');
  }
  return value.toString();
}
