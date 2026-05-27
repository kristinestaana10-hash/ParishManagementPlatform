import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
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

class ProfileScreen extends StatefulWidget {
  final String userName;
  final bool isTagalog;
  final VoidCallback onLogoutPressed;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.onLogoutPressed,
    this.isTagalog = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaving = false;
  bool _initialized = false;
  bool _ensuredUserRecord = false;
  String? _profileImageUrl;
  PlatformFile? _selectedImage;
  bool _isUploadingImage = false;
  String _barangay = '';

  // Google API key for address autocomplete
  static const String _googleApiKey = 'AIzaSyAoKG4IiO0--V0xgJjqSln2u1e-apsWYKY';

  // Address autocomplete
  List<dynamic> _addressSuggestions = [];
  bool _isLoadingAddressSuggestions = false;
  String? _addressApiError;
  Timer? _addressDebounceTimer;
  final FocusNode _addressFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseService.instance.auth.currentUser;
    if (currentUser != null) {
      _nameController.text = currentUser.displayName ?? widget.userName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
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
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(input)}'
        '&key=$_googleApiKey'
        '&components=country:PH'
        '&language=en',
      );

      final response = await http.get(url);
      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Geocode API Status: ${data['status']}');

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
    _addressController.text = suggestion['description'] ?? '';
    setState(() => _addressSuggestions = []);
    _addressFocusNode.unfocus();
  }

  Future<void> _pickProfileImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Important: get bytes for upload
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedImage = result.files.first;
        });

        // Auto-upload when image is selected
        await _uploadAndSaveProfileImage();
      }
    } catch (e) {
      _showModalNotificationGlobal(
        context,
        widget.isTagalog
            ? 'Hindi ma-upload ang larawan. Pakisubukang muli.'
            : 'Unable to upload image. Please try again.',
        bgColor: Colors.red,
      );
    }
  }

  Future<void> _uploadAndSaveProfileImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      // Upload to Firebase Storage
      final imageUrl = await FirebaseService.instance.uploadProfileImage(
        _selectedImage!,
      );

      if (imageUrl == null) {
        _showModalNotificationGlobal(
          context,
          widget.isTagalog
              ? 'Hindi ma-upload ang larawan. Subukang muli.'
              : 'Failed to upload image. Please try again.',
          bgColor: Colors.red,
        );
        return;
      }

      // Save URL to profile
      await FirebaseService.instance.updateCurrentUserProfile(
        profileImage: imageUrl,
      );

      setState(() {
        _profileImageUrl = imageUrl;
        _selectedImage = null;
      });

      _showModalNotificationGlobal(
        context,
        widget.isTagalog
            ? 'Na-upload na ang profile picture!'
            : 'Profile picture uploaded!',
        bgColor: ParishColors.greenSuccess,
      );
    } catch (e) {
      _showModalNotificationGlobal(
        context,
        widget.isTagalog ? 'Error: $e' : 'Error: $e',
        bgColor: Colors.red,
      );
    } finally {
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload profile image if selected
      String? imageUrl;
      if (_selectedImage != null) {
        // Upload to Firebase Storage
        imageUrl = await FirebaseService.instance.uploadProfileImage(
          _selectedImage!,
        );
        if (imageUrl != null) {
          _profileImageUrl = imageUrl;
        }
      }

      // Save profile (name is read-only, only phone, address, barangay and image can be updated)
      await FirebaseService.instance.updateCurrentUserProfile(
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        barangay: _barangay,
        profileImage: imageUrl,
      );

      _showModalNotificationGlobal(
        context,
        widget.isTagalog
            ? 'Na-update na ang profile!'
            : 'Profile updated successfully!',
        bgColor: ParishColors.greenSuccess,
      );
    } on Exception catch (e) {
      _showModalNotificationGlobal(
        context,
        e.toString().replaceAll('Exception: ', ''),
        bgColor: Colors.red,
      );
    } catch (e) {
      _showModalNotificationGlobal(
        context,
        widget.isTagalog
            ? 'Hindi ma-update ang profile. Pakisubukang muli.'
            : 'Unable to update profile. Please try again.',
        bgColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _selectedImage = null;
        });
      }
    }
  }

  void _initializeControllers(Map<String, dynamic>? data) {
    if (_initialized || data == null) return;

    _nameController.text = data['name'] as String? ?? widget.userName;
    _phoneController.text = data['phone'] as String? ?? '';
    _addressController.text = data['address'] as String? ?? '';
    _barangay = data['barangay'] as String? ?? '';
    _profileImageUrl = data['profileImage'] as String?;
    _initialized = true;
    
    // Force rebuild to display loaded data
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Widget _buildProfileImage() {
    // Show selected image preview (before upload)
    if (_selectedImage != null) {
      // For web - use bytes
      if (_selectedImage!.bytes != null) {
        return Image.memory(
          _selectedImage!.bytes!,
          fit: BoxFit.cover,
          width: 100,
          height: 100,
        );
      }
      // For mobile/desktop - use file path
      if (_selectedImage!.path != null) {
        return Image.file(
          File(_selectedImage!.path!),
          fit: BoxFit.cover,
          width: 100,
          height: 100,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultAvatar();
          },
        );
      }
    }

    // Show uploaded profile image from network
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return Image.network(
        _profileImageUrl!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar();
        },
      );
    }

    // Default avatar
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: ParishColors.bgBlue50,
      child: const Icon(Icons.person, size: 48, color: Colors.white),
    );
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional
    }
    // Must be exactly 11 digits starting with 09
    if (value.length != 11 || !value.startsWith('09')) {
      return widget.isTagalog
          ? 'Invalid format. Gamitin: 09XXXXXXXXX (11 digits)'
          : 'Invalid format. Use: 09XXXXXXXXX (11 digits)';
    }
    return null;
  }

  String _formatTimestamp(Object? timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.month}/${date.day}/${date.year}';
    }
    if (timestamp is DateTime) {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
    return '-';
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length < 2) return email;
    final local = parts[0];
    final domain = parts.sublist(1).join('@');
    final n = local.length;
    if (n <= 1) return email; // nothing to mask use original
    final show = (n / 2).ceil();
    final maskedCount = n - show;
    final masked = local.substring(0, show) + List.filled(maskedCount, '*').join();
    return '$masked@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ParishBreakpoints.isMobile(context);
    final currentUser = FirebaseService.instance.auth.currentUser;

    if (currentUser == null) {
      return Center(
        child: Text(
          widget.isTagalog
              ? 'Paki-login muna upang makita ang profile.'
              : 'Please sign in to view your profile.',
          style: TextStyle(color: ParishColors.textBlue900),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseService.instance.userProfileStream(),
      builder: (context, snapshot) {
        final profileData = snapshot.data?.data();

        if (profileData == null && !_ensuredUserRecord) {
          _ensuredUserRecord = true;
          FirebaseService.instance.ensureUserRecord(currentUser).then((_) {
            if (mounted) setState(() {});
          });
        }

        if (!_initialized && profileData != null) {
          _initializeControllers(profileData);
        }

        final email =
            profileData?['email'] as String? ?? currentUser.email ?? '';
        final birthdayData = profileData?['birthday'];
        final birthday = birthdayData is Timestamp
            ? birthdayData.toDate()
            : birthdayData is DateTime
                ? birthdayData
                : birthdayData is String
                    ? DateTime.tryParse(birthdayData)
                    : null;
        final status =
            profileData?['status'] as String? ??
            (widget.isTagalog ? 'Aktibong Parokiyano' : 'Active Parishioner');
        final barangay = profileData?['barangay'] as String? ?? '';
        final createdAt =
            profileData?['createdAt'] ?? currentUser.metadata.creationTime;

        return SingleChildScrollView(
          child: ParishResponsiveScaffold(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: ParishGradients.blueHeroGradient,
                    borderRadius: BorderRadius.circular(20.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(isMobile ? 20.0 : 24.0),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ParishColors.primaryGold,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: ClipOval(child: _buildProfileImage()),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: ParishColors.primaryGold,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: _isUploadingImage
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      Text(
                        _nameController.text.isNotEmpty
                            ? _nameController.text
                            : widget.userName,
                        style: const TextStyle(
                          fontSize: 22,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          color: ParishColors.blue200,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),
                Text(
                  widget.isTagalog ? 'Impormasyon' : 'Information',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: ParishColors.textBlue900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16.0),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Name - Read only (cannot be changed)
                      _buildInfoCard(
                        icon: Icons.person,
                        label: widget.isTagalog ? 'Pangalan' : 'Name',
                        value: _nameController.text.isNotEmpty
                            ? _nameController.text
                            : widget.userName,
                      ),
                      const SizedBox(height: 12.0),
                      _buildInfoCard(
                        icon: Icons.email,
                        label: widget.isTagalog ? 'Email' : 'Email',
                        value: _maskEmail(email),
                      ),
                      const SizedBox(height: 12.0),
                      _buildTextField(
                        controller: _phoneController,
                        label: widget.isTagalog ? 'Telepono' : 'Phone',
                        icon: Icons.phone,
                        hint: '09XXXXXXXXX',
                        validator: _validatePhone,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          PhilippinePhoneInputFormatter(),
                          LengthLimitingTextInputFormatter(11),
                        ],
                      ),
                      const SizedBox(height: 12.0),
                      _buildInfoCard(
                        icon: Icons.map,
                        label: widget.isTagalog ? 'Barangay' : 'Barangay',
                        value: barangay.isNotEmpty ? barangay : '-',
                      ),
                      const SizedBox(height: 12.0),
                      _buildInfoCard(
                        icon: Icons.location_on,
                        label: widget.isTagalog ? 'Direksyon' : 'Address',
                        value: _addressController.text.isNotEmpty
                            ? _addressController.text
                            : '-',
                      ),
                      const SizedBox(height: 12.0),
                      _buildInfoCard(
                        icon: Icons.cake,
                        label: widget.isTagalog ? 'Kaarawan' : 'Birthday',
                        value: birthday != null
                            ? _formatTimestamp(birthday)
                            : '-',
                      ),
                      const SizedBox(height: 12.0),
                      _buildInfoCard(
                        icon: Icons.calendar_today,
                        label: widget.isTagalog
                            ? 'Miyembro simula'
                            : 'Member since',
                        value: _formatTimestamp(createdAt),
                      ),
                      const SizedBox(height: 24.0),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ParishColors.primaryGold,
                            foregroundColor: ParishColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: _isSaving
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                )
                              : Text(
                                  widget.isTagalog
                                      ? 'I-save ang Profile'
                                      : 'Save Profile',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onLogoutPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: Text(
                            widget.isTagalog ? 'Mag-logout' : 'Log out',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    String? hint,
    TextInputType? keyboardType,
    bool enabled = true,
    List<TextInputFormatter>? inputFormatters,
    FocusNode? focusNode,
    void Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      validator: validator,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: ParishColors.primaryGold),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: ParishColors.borderBlue100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: ParishColors.primaryGold, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: enabled
            ? ParishColors.bgBlue50.withValues(alpha: 0.3)
            : Colors.grey.shade100,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: ParishColors.bgBlue50,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: ParishColors.borderBlue100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: ParishColors.borderBlue100,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(icon, color: ParishColors.primaryBlue),
          ),
          const SizedBox(width: 16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ParishColors.textGray600,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: ParishColors.textBlue900,
                    fontWeight: FontWeight.w500,
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
