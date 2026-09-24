import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/parish_profile.dart';
import '../models/scheduling_conflict_model.dart';
import 'document_validation_service.dart';
import 'scheduling_conflict_service.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  /// Upload profile image to Firebase Storage and return download URL
  Future<String?> uploadProfileImage(PlatformFile imageFile) async {
    final user = auth.currentUser;
    if (user == null) return null;

    try {
      // Create a unique file path
      final fileName =
          'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child('profile_images/$fileName');

      UploadTask uploadTask;

      // Upload file - handle both web (bytes) and mobile/desktop (file path)
      if (imageFile.bytes != null) {
        // Web platform - use bytes
        uploadTask = ref.putData(
          imageFile.bytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else if (imageFile.path != null) {
        // Mobile/Desktop - use file path
        final file = io.File(imageFile.path!);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        debugPrint('No bytes or path available for upload');
        return null;
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Profile image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  String get currentUid => auth.currentUser?.uid ?? '';
  String get currentUserName => auth.currentUser?.displayName ?? 'Guest';
  String get currentUserEmail => auth.currentUser?.email ?? '';

  /// Generate a structured ID with auto-incrementing number
  /// Format: prefix_001, prefix_002, etc.
  Future<String> generateStructuredId(String prefix) async {
    try {
      // Reference to the counter document
      final counterRef = firestore.collection('counters').doc(prefix);

      // Use Firestore transaction to ensure atomic increment
      final result = await firestore.runTransaction((transaction) async {
        final counterDoc = await transaction.get(counterRef);

        int currentCount = 0;
        if (counterDoc.exists) {
          currentCount = counterDoc.data()?['count'] ?? 0;
        }

        // Increment count
        final newCount = currentCount + 1;

        // Update counter document
        if (counterDoc.exists) {
          transaction.update(counterRef, {'count': newCount});
        } else {
          transaction.set(counterRef, {
            'count': newCount,
            'createdAt': FieldValue.serverTimestamp(),
            'prefix': prefix,
          });
        }

        // Return formatted ID with leading zeros
        return '${prefix}_${newCount.toString().padLeft(3, '0')}';
      });

      return result;
    } catch (e) {
      debugPrint('Error generating structured ID: $e');
      // Fallback to timestamp-based ID if counter fails
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${prefix}_$timestamp';
    }
  }

  Future<void> _createUserRecord(User? user) async {
    if (user == null) return;

    // Generate structured ID for user
    final structuredId = await generateStructuredId('user');

    await firestore.collection('users').doc(structuredId).set({
      'uid': user.uid, // Keep Firebase Auth UID for authentication
      'structuredId': structuredId, // New structured ID
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'role': 'parishioner',
      'status': 'active',
      'profileImage': user.photoURL ?? '',
      'phone': user.phoneNumber ?? '',
      'birthday': null, // Initialize as null - user will set this
      'barangay': '', // Initialize as empty - user will set this
      'address': '', // Initialize as empty - user will set this
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateUserProfile(User? user) async {
    if (user == null) return;

    // Find user document by Firebase Auth UID
    final query = await firestore
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final docRef = query.docs.first.reference;
      await docRef.set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> ensureUserRecord(User user) async {
    // Check if user record exists by Firebase Auth UID
    final query = await firestore
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      await _createUserRecord(user);
    }
  }

  Stream<User?> get _authUserStream {
    return Stream<User?>.multi((controller) {
      controller.add(auth.currentUser);
      final subscription = auth.userChanges().listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userProfileStream() {
    return _authUserStream.asyncExpand((user) {
      if (user == null) {
        return const Stream.empty();
      }
      // Query user by Firebase Auth UID since we now use structured IDs as document IDs
      return firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .snapshots()
          .map((snapshot) => snapshot.docs.first);
    });
  }

  /// Get current user data as a one-time fetch
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = auth.currentUser;
    if (user == null) return null;

    try {
      final query = await firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current user data: $e');
      return null;
    }
  }

  /// Check if user can change their name (30-day restriction)
  Future<Map<String, dynamic>> canChangeName() async {
    final user = auth.currentUser;
    if (user == null) {
      return {
        'canChange': false,
        'daysRemaining': 0,
        'message': 'Not authenticated',
      };
    }

    // Find user document by Firebase Auth UID
    final query = await firestore
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return {'canChange': true, 'daysRemaining': 0};
    }

    final data = query.docs.first.data();

    if (data['lastNameChange'] == null) {
      return {'canChange': true, 'daysRemaining': 0};
    }

    final lastChange = data['lastNameChange'] as Timestamp?;
    if (lastChange == null) {
      return {'canChange': true, 'daysRemaining': 0};
    }

    final lastChangeDate = lastChange.toDate();
    final now = DateTime.now();
    final difference = now.difference(lastChangeDate);
    final daysRemaining = 30 - difference.inDays;

    if (daysRemaining > 0) {
      return {
        'canChange': false,
        'daysRemaining': daysRemaining,
        'message': 'You can change your name again in $daysRemaining days',
      };
    }

    return {'canChange': true, 'daysRemaining': 0};
  }

  /// Validate Philippine phone number format
  bool isValidPhilippinePhoneNumber(String phone) {
    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'\D'), '');

    // Check for +63 format: +639XXXXXXXXX (13 digits with +, 12 without)
    // or 09XXXXXXXXX (11 digits)
    final localFormat = RegExp(r'^09\d{9}$');
    final intlFormat = RegExp(r'^639\d{9}$');

    return localFormat.hasMatch(digitsOnly) || intlFormat.hasMatch(digitsOnly);
  }

  Future<void> updateCurrentUserProfile({
    String? name,
    String? phone,
    String? address,
    String? barangay,
    String? profileImage,
  }) async {
    final user = auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'User must be signed in to update profile.',
      );
    }

    // Check name change restriction
    if (name != null && name.trim().isNotEmpty) {
      final nameCheck = await canChangeName();
      if (!nameCheck['canChange']) {
        throw Exception(nameCheck['message']);
      }

      await user.updateDisplayName(name.trim());
      await user.reload();
    }

    // Validate phone number
    if (phone != null && phone.trim().isNotEmpty) {
      if (!isValidPhilippinePhoneNumber(phone)) {
        throw Exception(
          'Invalid phone number. Use format: 09XXXXXXXXX or +639XXXXXXXXX',
        );
      }
    }

    await ensureUserRecord(user);

    // Find user document by Firebase Auth UID
    final query = await firestore
        .collection('users')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('User record not found');
    }

    final updateData = <String, dynamic>{
      if (name != null && name.trim().isNotEmpty) ...{
        'name': name.trim(),
        'lastNameChange': FieldValue.serverTimestamp(),
      },
      if (phone != null) 'phone': phone.trim(),
      if (address != null) 'address': address.trim(),
      if (barangay != null) 'barangay': barangay.trim(),
      'profileImage': ?profileImage,
      'email': user.email ?? '',
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    await query.docs.first.reference.set(updateData, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getUserSacramentRequestsStream() {
    return auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return const Stream.empty();
      }
      return firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .snapshots();
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> userBookingsStream() {
    return getUserSacramentRequestsStream();
  }

  /// Save sacrament requirements to Firebase
  Future<String> saveSacramentRequirement({
    required String sacramentType,
    required String requirementType,
    required PlatformFile documentFile,
    String? bookingId,
  }) async {
    debugPrint('DEBUG: Starting saveSacramentRequirement');
    debugPrint('DEBUG: sacramentType: $sacramentType');
    debugPrint('DEBUG: requirementType: $requirementType');
    debugPrint('DEBUG: documentFile.name: ${documentFile.name}');

    final currentUser = auth.currentUser;
    if (currentUser == null) {
      debugPrint('DEBUG: User not authenticated');
      throw Exception('User must be signed in to save sacrament requirements');
    }

    debugPrint('DEBUG: User authenticated: ${currentUser.uid}');

    // Generate structured ID for requirement
    final structuredId = await generateStructuredId('requirement');
    debugPrint('DEBUG: Generated structuredId: $structuredId');

    // Upload document to Firebase Storage
    String? documentUrl;
    if (documentFile.bytes != null || documentFile.path != null) {
      debugPrint('DEBUG: Starting document upload');
      documentUrl = await _uploadRequirementDocument(
        documentFile: documentFile,
        userId: currentUser.uid,
        requirementId: structuredId,
      );
      debugPrint('DEBUG: Document uploaded to: $documentUrl');
    } else {
      debugPrint('DEBUG: No document bytes or path found');
    }

    // Save requirement metadata to Firestore
    final requirementData = <String, dynamic>{
      'structuredId': structuredId,
      'userId': currentUser.uid,
      'userName': currentUser.displayName ?? 'User',
      'userEmail': currentUser.email ?? '',
      'sacramentType': sacramentType,
      'requirementType': requirementType,
      'bookingId': bookingId,
      'documentUrl': documentUrl,
      'documentName': documentFile.name,
      'documentSize': documentFile.size,
      'uploadedAt': FieldValue.serverTimestamp(),
      'status': 'pending', // pending, approved, rejected
      'validationResult': null, // Will be populated after validation
    };

    debugPrint('DEBUG: Saving requirement data to Firestore');
    debugPrint(
      'DEBUG: Requirement data keys: ${requirementData.keys.toList()}',
    );

    try {
      await firestore
          .collection('requirements')
          .doc(structuredId)
          .set(requirementData);
      debugPrint('DEBUG: Successfully saved requirement to Firestore');
    } catch (e) {
      debugPrint('DEBUG: Error saving to Firestore: $e');
      rethrow;
    }

    return structuredId;
  }

  /// Upload requirement document to Firebase Storage
  Future<String?> _uploadRequirementDocument({
    required PlatformFile documentFile,
    required String userId,
    required String requirementId,
  }) async {
    try {
      // Create a unique file path
      final fileName = '${userId}_${requirementId}_${documentFile.name}';
      final ref = storage.ref().child('requirements/$fileName');

      UploadTask uploadTask;

      // Upload file - handle both web (bytes) and mobile/desktop (file path)
      if (documentFile.bytes != null) {
        // Web platform - use bytes
        uploadTask = ref.putData(
          documentFile.bytes!,
          SettableMetadata(contentType: _getContentType(documentFile.name)),
        );
      } else if (documentFile.path != null) {
        // Mobile/Desktop - use file path
        final file = io.File(documentFile.path!);
        uploadTask = ref.putFile(
          file,
          SettableMetadata(contentType: _getContentType(documentFile.name)),
        );
      } else {
        debugPrint('No bytes or path available for upload');
        return null;
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Requirement document uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading requirement document: $e');
      return null;
    }
  }

  /// Get content type based on file extension
  String _getContentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
      case 'docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get user's sacrament requirements
  Stream<QuerySnapshot<Map<String, dynamic>>> getUserRequirementsStream() {
    return auth.authStateChanges().asyncExpand((user) {
      if (user == null) {
        return const Stream.empty();
      }
      return firestore
          .collection('requirements')
          .where('userId', isEqualTo: user.uid)
          .orderBy('uploadedAt', descending: true)
          .snapshots();
    });
  }

  /// Update requirement status (approve/reject)
  Future<void> updateRequirementStatus({
    required String requirementId,
    required String status,
    String? adminNotes,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (adminNotes != null) {
      updateData['adminNotes'] = adminNotes;
    }

    await firestore
        .collection('requirements')
        .doc(requirementId)
        .update(updateData);
  }

  /// Save validation result for requirement
  Future<void> saveRequirementValidationResult({
    required String requirementId,
    required DocumentValidationResult validationResult,
  }) async {
    final validationResultData = <String, dynamic>{
      'isValid': validationResult.isValid,
      'missingFields': validationResult.missingFields,
      'invalidFields': validationResult.invalidFields,
      'warnings': validationResult.warnings,
      'confidenceScore': validationResult.confidenceScore,
      'extractedData': validationResult.extractedData,
      'errorMessage': validationResult.errorMessage,
      'validatedAt': FieldValue.serverTimestamp(),
    };

    await firestore.collection('requirements').doc(requirementId).update({
      'validationResult': validationResultData,
      'status': validationResult.isValid ? 'approved' : 'pending_review',
    });
  }

  String _canonicalSacramentTypeKey(String value) {
    final s = value.toLowerCase();
    if (s.contains('bapt') || s.contains('binyag')) return 'baptism';
    if (s.contains('confirm') || s.contains('kumpil')) return 'confirmation';
    if (s.contains('wedding') ||
        s.contains('kasal') ||
        s.contains('matrimony')) {
      return 'wedding';
    }
    if (s.contains('funeral') || s.contains('yumao')) return 'funeral';
    if ((s.contains('house') && s.contains('bless')) ||
        (s.contains('basbas') && s.contains('bahay'))) {
      return 'house_blessing';
    }
    if (s.contains('anoint') || s.contains('pagpapahid')) return 'anointing';
    if ((s.contains('first') && s.contains('communion')) ||
        (s.contains('unang') && s.contains('komunyon'))) {
      return 'first_communion';
    }
    if ((s.contains('mass') && s.contains('intention')) ||
        (s.contains('intensyon') && s.contains('misa'))) {
      return 'mass_intention';
    }
    return '';
  }

  String _extractFirstDateFromDetails(Map<String, dynamic> details) {
    final fields = details['fields'] as Map<String, dynamic>? ?? {};
    for (final entry in fields.entries) {
      final key = entry.key.toString().toLowerCase();
      final val = (entry.value ?? '').toString();
      if (key.contains('date') || key.contains('petsa')) {
        final m = RegExp(r'\b(\d{4}-\d{2}-\d{2})\b').firstMatch(val);
        if (m != null) return m.group(1) ?? '';
      }
    }
    return '';
  }

  String _extractFirstTimeFromDetails(Map<String, dynamic> details) {
    final fields = details['fields'] as Map<String, dynamic>? ?? {};
    for (final entry in fields.entries) {
      final key = entry.key.toString().toLowerCase();
      final val = (entry.value ?? '')
          .toString()
          .replaceAll('\u00A0', ' ')
          .replaceAll('\u202F', ' ');
      if (key.contains('time') || key.contains('oras')) {
        final m = RegExp(
          r'\b(\d{1,2}(?::\d{2})?[\s\u00A0\u202F]*(?:[AaPp][Mm])?)\b',
        ).firstMatch(val);
        if (m != null) return (m.group(1) ?? '').trim();
      }
    }
    return '';
  }

  String _extractScheduleDateFromDetails(
    Map<String, dynamic> details,
    String typeKey,
  ) {
    final fields = details['fields'] as Map<String, dynamic>? ?? {};
    final candidates = switch (typeKey) {
      'baptism' => [fields['Registration - Date of Baptism']],
      'confirmation' => [fields['Date of Confirmation (Petsa ng Kumpil)']],
      'wedding' => [fields['Date of Wedding']],
      'funeral' => [
        fields['Burial Date'],
        fields['Burial Date (Petsa ng Libing)'],
      ],
      'house_blessing' => [fields['Date of Blessing']],
      'anointing' => [fields['Appointment Date']],
      'mass_intention' => [
        fields['Date of Mass (Petsa ng Misa)'],
        fields['Date of Mass'],
        fields['Mass Intention Date'],
        fields['Date of Mass Intention'],
      ],
      'first_communion' => [
        fields['Preferred Date (Petsa na Nais)'],
        fields['Date of First Communion'],
        fields['First Communion Date'],
      ],
      _ => const [],
    };

    for (final value in candidates) {
      final date = _extractDateFromValue(value);
      if (date.isNotEmpty) return date;
    }

    return _extractFirstDateFromDetails(details);
  }

  String _extractScheduleTimeFromDetails(
    Map<String, dynamic> details,
    String typeKey,
  ) {
    final fields = details['fields'] as Map<String, dynamic>? ?? {};
    final candidates = switch (typeKey) {
      'baptism' => [fields['Registration - Time of Baptism']],
      'confirmation' => [fields['Time (Oras)']],
      'wedding' => [fields['Time']],
      'funeral' => [
        fields['Burial Time'],
        fields['Burial Time (Oras ng Libing)'],
      ],
      'house_blessing' => [fields['Time of Blessing']],
      'anointing' => [fields['Appointment Time']],
      'mass_intention' => [
        fields['Time of Mass (Oras ng Misa)'],
        fields['Time of Mass'],
        fields['Mass Intention Time'],
        fields['Time of Mass Intention'],
      ],
      'first_communion' => [
        fields['Preferred Time (Oras na Nais)'],
        fields['Time of First Communion'],
        fields['First Communion Time'],
      ],
      _ => const [],
    };

    for (final value in candidates) {
      final time = _extractTimeFromValue(value);
      if (time.isNotEmpty) return time;
    }

    return _extractFirstTimeFromDetails(details);
  }

  String _extractDateFromValue(dynamic value) {
    final val = (value ?? '').toString();
    final match = RegExp(r'\b(\d{4}-\d{2}-\d{2})\b').firstMatch(val);
    return match?.group(1) ?? '';
  }

  String _extractTimeFromValue(dynamic value) {
    final val = (value ?? '')
        .toString()
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ');
    final match = RegExp(
      r'\b(\d{1,2}(?::\d{2})?[\s\u00A0\u202F]*(?:[AaPp][Mm])?)\b',
    ).firstMatch(val);
    return (match?.group(1) ?? '').trim();
  }

  Stream<int> userBookingsCountStream() {
    return userBookingsStream().map((snapshot) => snapshot.docs.length);
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    try {
      await _updateUserProfile(credential.user);
      if (credential.user != null) {
        await ensureUserRecord(credential.user!);
      }
    } catch (e, st) {
      debugPrint('Failed to update user profile on login: $e\n$st');
    }

    return credential;
  }

  Future<void> requestSignupOtp({required String email}) async {
    final callable = functions.httpsCallable('requestSignupOtp');
    await callable.call(<String, dynamic>{'email': email.trim()});
  }

  Future<UserCredential> verifySignupOtpAndCreateAccount({
    String? firstName,
    String? lastName,
    required String email,
    required String password,
    required String otp,
    String? phone,
    String? address,
    String? barangay,
    String? sex,
    DateTime? birthday,
  }) async {
    final callable = functions.httpsCallable('verifySignupOtpAndCreateAccount');
    await callable.call(<String, dynamic>{
      'firstName': firstName?.trim(),
      'lastName': lastName?.trim(),
      'email': email.trim(),
      'password': password,
      'otp': otp.trim(),
      'sex': sex?.trim(),
      'birthday': birthday?.toIso8601String(),
      'address': address?.trim(),
      'barangay': barangay?.trim(),
    });

    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    try {
      await _updateUserProfile(credential.user);
      if (credential.user != null) {
        await ensureUserRecord(credential.user!);
        // Update user record with additional signup info
        await _updateUserProfileWithSignupData(
          credential.user!,
          phone: phone,
          address: address,
          barangay: barangay,
          sex: sex,
          birthday: birthday,
          firstName: firstName,
          lastName: lastName,
        );
      }
    } catch (e, st) {
      debugPrint('Failed to update user profile after OTP signup: $e\n$st');
    }

    return credential;
  }

  Future<void> _updateUserProfileWithSignupData(
    User user, {
    String? phone,
    String? address,
    String? barangay,
    String? sex,
    DateTime? birthday,
    String? firstName,
    String? lastName,
  }) async {
    try {
      // Find user document by Firebase Auth UID
      final query = await firestore
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final docRef = query.docs.first.reference;
        final updateData = <String, dynamic>{
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (phone != null && phone.isNotEmpty) {
          updateData['phone'] = phone;
        }
        if (address != null && address.isNotEmpty) {
          updateData['address'] = address;
        }
        if (barangay != null && barangay.isNotEmpty) {
          updateData['barangay'] = barangay;
        }
        if (firstName != null && firstName.isNotEmpty) {
          updateData['firstName'] = firstName;
        }
        if (lastName != null && lastName.isNotEmpty) {
          updateData['lastName'] = lastName;
        }
        if (sex != null && sex.isNotEmpty) {
          updateData['sex'] = sex;
        }
        if (birthday != null) {
          updateData['birthday'] = Timestamp.fromDate(birthday);
        }

        await docRef.update(updateData);
      }
    } catch (e) {
      debugPrint('Failed to update user profile with signup data: $e');
    }
  }

  Future<UserCredential> signUp({
    String? firstName,
    String? lastName,
    required String email,
    required String password,
    String? phone,
    String? address,
    String? barangay,
    String? sex,
    DateTime? birthday,
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'Signup failed: no user was returned from Firebase.',
      );
    }

    final displayName = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    if (displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
    }
    await user.reload();

    try {
      await ensureUserRecord(user);
      await _updateUserProfileWithSignupData(
        user,
        phone: phone,
        address: address,
        barangay: barangay,
        sex: sex,
        birthday: birthday,
        firstName: firstName,
        lastName: lastName,
      );
    } catch (e, st) {
      debugPrint('Failed to create user record after signup: $e\n$st');
    }

    return credential;
  }

  Future<void> signOut() async {
    if (auth.currentUser != null) {
      await auth.signOut();
    }
  }

  Future<void> submitDonation(Map<String, dynamic> donation) async {
    final currentUser = auth.currentUser;
    final donationType = donation['donationType']?.toString() ?? 'unknown';

    // Generate structured ID for donation
    final structuredId = await generateStructuredId('donation');

    // Handle both authenticated and guest users
    String userName = '';
    String userEmail = '';
    String userId = '';

    if (currentUser != null) {
      // Authenticated user
      userName = currentUser.displayName?.trim() ?? '';
      userEmail = currentUser.email?.trim() ?? '';
      userId = currentUser.uid;

      debugPrint(
        'DEBUG: Authenticated user - uid: "${currentUser.uid}", displayName: "${currentUser.displayName}", email: "${currentUser.email}"',
      );
    } else {
      // Guest user
      userId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('DEBUG: Guest user - generated userId: "$userId"');
    }

    // Check if this is an anonymous donation
    final isAnonymous = donation['isAnonymous'] == true;

    // Use form data for guest users or as fallback for authenticated users
    if (userName.isEmpty) {
      userName = donation['name']?.toString().trim() ?? '';
    }
    if (userEmail.isEmpty) {
      userEmail = donation['email']?.toString().trim() ?? '';
    }

    // For anonymous donations, set defaults and skip validation
    if (isAnonymous) {
      if (userName.isEmpty) {
        userName = 'Anonymous';
      }
      // Email is optional for anonymous - use placeholder if not provided
      if (userEmail.isEmpty) {
        userEmail = 'anonymous@donation.local';
      }
    } else {
      // Non-anonymous donations require name and email
      if (userName.isEmpty) {
        throw Exception('User name is required. Please provide your name.');
      }
      if (userEmail.isEmpty) {
        throw Exception('User email is required. Please provide your email.');
      }
    }

    // Basic email validation (only if email is provided and not the placeholder)
    if (userEmail != 'anonymous@donation.local' &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(userEmail)) {
      throw Exception('Please provide a valid email address.');
    }

    debugPrint(
      'DEBUG: Final validated - userName: "$userName", userEmail: "$userEmail", userId: "$userId"',
    );
    debugPrint('DEBUG: Raw donation data: $donation');

    // Build donation data based on donation type
    final donationData = <String, dynamic>{
      'structuredId': structuredId, // New structured ID
      'userId': userId,
      'userName': userName, // Properly mapped field
      'userEmail': userEmail, // Properly mapped field
      'donationType': donationType,
      'isAnonymous': donation['isAnonymous'] ?? false,
      'name': (donation['name']?.toString().trim().isNotEmpty ?? false)
          ? donation['name'].toString().trim()
          : userName, // Keep for backward compatibility
      'email': (donation['email']?.toString().trim().isNotEmpty ?? false)
          ? donation['email'].toString().trim()
          : userEmail, // Keep for backward compatibility
      'phone': donation['phone'] ?? '',
      'message': donation['message'] ?? '',
      'submittedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    };

    // Add fields based on donation type
    if (donationType == 'monetary') {
      final amountValue =
          double.tryParse(donation['amount']?.toString() ?? '') ?? 0.0;
      if (amountValue <= 0) {
        throw Exception('Amount must be greater than 0 for monetary donations');
      }
      donationData['amount'] = amountValue;
      donationData['currency'] = donation['currency'] ?? 'PHP';
      donationData['paymentMethod'] = donation['paymentMethod'] ?? '';
      donationData['items'] = donation['items'] ?? '';
      donationData['description'] = donation['description'] ?? '';
    } else if (donationType == 'inKind') {
      // In-kind donations - no amount field
      donationData['items'] = donation['items'] ?? '';
      donationData['description'] = donation['description'] ?? '';
      // Don't add amount, currency, or paymentMethod for in-kind
    } else if (donationType == 'massOffering') {
      final amountValue =
          double.tryParse(donation['amount']?.toString() ?? '') ?? 0.0;
      if (amountValue <= 0) {
        throw Exception('Amount must be greater than 0 for mass offerings');
      }
      donationData['amount'] = amountValue;
      donationData['currency'] = donation['currency'] ?? 'PHP';
      donationData['paymentMethod'] = donation['paymentMethod'] ?? '';
      donationData['items'] = donation['items'] ?? '';
      donationData['description'] = donation['description'] ?? '';
      donationData['offeringLocation'] = donation['offeringLocation'] ?? '';
    } else if (donationType == 'other') {
      // Other donations - no amount field
      donationData['description'] = donation['description'] ?? '';
      // Don't add amount, currency, or paymentMethod for other
    }

    debugPrint('DEBUG: Final donation data being sent to Firestore:');
    debugPrint('DEBUG: Donation type: "$donationType"');
    donationData.forEach((key, value) {
      debugPrint('  $key: ${value.runtimeType} = "$value"');
    });
    debugPrint(
      'DEBUG: All keys in donationData: ${donationData.keys.toList()}',
    );

    // Final validation before submission
    if (donationData['userName'] == null ||
        donationData['userName'].toString().trim().isEmpty) {
      throw Exception('userName is required and must be a non-empty string');
    }
    if (donationData['userEmail'] == null ||
        donationData['userEmail'].toString().trim().isEmpty) {
      throw Exception('userEmail is required and must be a non-empty string');
    }

    try {
      await firestore
          .collection('donations')
          .doc(structuredId)
          .set(donationData);
      debugPrint('DEBUG: Donation successfully saved to Firestore');
    } catch (e) {
      debugPrint('ERROR: Failed to save donation to Firestore: $e');
      debugPrint('ERROR: Error details: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createXenditDonationInvoice({
    required double amount,
    required bool isAnonymous,
    required String name,
    required String email,
    required String userName,
    required String userEmail,
    String donationType = 'monetary',
    String phone = '',
    String items = '',
    String description = '',
    String message = '',
    String offeringLocation = '',
    String paymentReturnType = 'donation',
  }) async {
    final callable = functions.httpsCallable('createXenditDonationInvoice');
    final result = await callable.call(<String, dynamic>{
      'amount': amount,
      'isAnonymous': isAnonymous,
      'name': name,
      'email': email,
      'userName': userName, // Add correct field name
      'userEmail': userEmail, // Add correct field name
      'donationType': donationType,
      'phone': phone,
      'items': items,
      'description': description,
      'message': message,
      'offeringLocation': offeringLocation,
      'paymentReturnType': paymentReturnType,
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createXenditMassOfferingInvoice({
    required double amount,
    required bool isAnonymous,
    required String name,
    required String email,
    required String userName,
    required String userEmail,
    String donationType = 'massOffering',
    String phone = '',
    String items = '',
    String description = '',
    String message = '',
    String offeringLocation = '',
  }) async {
    final callable = functions.httpsCallable('createXenditMassOfferingInvoice');
    final result = await callable.call(<String, dynamic>{
      'amount': amount,
      'isAnonymous': isAnonymous,
      'name': name,
      'email': email,
      'userName': userName,
      'userEmail': userEmail,
      'donationType': donationType,
      'phone': phone,
      'items': items,
      'description': description,
      'message': message,
      'offeringLocation': offeringLocation,
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> submitNonMonetaryDonation({
    required String donationType,
    required bool isAnonymous,
    required String name,
    required String email,
    required String userName,
    required String userEmail,
    String paymentMethod = 'cash',
    String phone = '',
    String items = '',
    String description = '',
    String message = '',
    int quantity = 1, // Add quantity parameter
  }) async {
    final callable = functions.httpsCallable('submitNonMonetaryDonation');

    // Build data payload without amount field for non-monetary donations
    final Map<String, dynamic> data = {
      'donationType': donationType,
      'isAnonymous': isAnonymous,
      'name': name,
      'email': email,
      'userName': userName, // Add correct field name
      'userEmail': userEmail, // Add correct field name
      'phone': phone,
      'message': message,
      'quantity': quantity, // Add quantity field
    };

    // Only add amount for monetary donations
    if (donationType == 'monetary') {
      data['amount'] = 0.0; // Default amount for monetary
    }

    // Add conditional fields based on donation type
    if (donationType == 'monetary') {
      data['paymentMethod'] = paymentMethod;
      data['currency'] = 'PHP';
    } else if (donationType == 'inKind') {
      data['paymentMethod'] = 'in-kind';
      data['items'] = items;
      data['description'] = description;
    } else if (donationType == 'other') {
      data['paymentMethod'] = 'other';
      data['description'] = description;
    }

    debugPrint(
      'DEBUG: Calling submitNonMonetaryDonation Cloud Function with data:',
    );
    debugPrint('DEBUG: Donation type: "${data['donationType']}"');
    data.forEach((key, value) {
      debugPrint('  $key: ${value.runtimeType} = "$value"');
    });
    debugPrint(
      'DEBUG: All keys being sent to Cloud Function: ${data.keys.toList()}',
    );

    final result = await callable.call(data);
    final responseData = result.data;
    if (responseData is Map) {
      return Map<String, dynamic>.from(responseData);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createXenditBookingInvoice({
    required double amount,
    required String sacramentType,
    String? bookingId,
    required Map<String, dynamic> details,
    required Map<String, dynamic> feeBreakdown,
    String? userName,
    String? userEmail,
  }) async {
    final callable = functions.httpsCallable('createXenditBookingInvoice');
    var resolvedUserName = userName?.trim() ?? '';
    if (resolvedUserName.isEmpty) {
      resolvedUserName = currentUserName.trim();
    }
    if (resolvedUserName.isEmpty) {
      resolvedUserName = 'Parishioner';
    }

    var resolvedUserEmail = userEmail?.trim() ?? '';
    if (resolvedUserEmail.isEmpty) {
      resolvedUserEmail = currentUserEmail.trim();
    }
    if (resolvedUserEmail.isEmpty) {
      resolvedUserEmail = 'no-reply@parish.local';
    }

    final payload = <String, dynamic>{
      'amount': amount,
      'sacramentType': sacramentType,
      'details': details,
      'feeBreakdown': feeBreakdown,
      'userName': resolvedUserName,
      'userEmail': resolvedUserEmail,
    };
    if (bookingId != null && bookingId.trim().isNotEmpty) {
      payload['bookingId'] = bookingId.trim();
    }

    final result = await callable.call(payload);
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getBookingAvailability({
    required String date,
    String time = '',
    String sacramentType = '',
  }) async {
    final callable = functions.httpsCallable('getBookingAvailability');
    final result = await callable.call(<String, dynamic>{
      'date': date,
      'time': time,
      'sacramentType': sacramentType,
    });
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }

  /// Returns only requested form keys that have a `booking_requirements`
  /// record. This is intended for listing cards on the home page and uses one
  /// bounded collection read instead of issuing many queries for every card.
  Future<Set<String>> getAvailableBookingFormKeys(
    Iterable<String> formKeys,
  ) async {
    final requestedKeys = formKeys
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toSet();
    if (requestedKeys.isEmpty) return <String>{};

    final records = await Future.wait(
      const ['booking_requirements'].map((collectionName) async {
        try {
          return await firestore
              .collection(collectionName)
              .limit(100)
              .get()
              .timeout(const Duration(seconds: 10));
        } catch (error) {
          debugPrint('Failed to load $collectionName form list: $error');
          return null;
        }
      }),
    );

    final availableKeys = <String>{};
    for (final key in requestedKeys) {
      for (final snapshot in records) {
        if (snapshot == null) continue;
        final matchesForm = snapshot.docs.any((form) {
          final data = form.data();
          final candidates = <Object?>[
            form.id,
            data['formKey'],
            data['sacramentTypeKey'],
            data['bookingType'],
            data['sacramentType'],
            data['serviceType'],
            data['name'],
            data['title'],
            data['formName'],
          ];
          return candidates.any(
            (value) => _bookingFormKeysMatch(value?.toString() ?? '', key),
          );
        });
        if (matchesForm) {
          availableKeys.add(key);
          break;
        }
      }
    }
    return availableKeys;
  }

  /// The redirect from Xendit is navigation only.  This asks the server to
  /// retrieve the invoice from Xendit before the app acknowledges a payment.
  Future<String> getVerifiedXenditPaymentStatus({
    required String paymentId,
    required String paymentType,
  }) async {
    final callable = functions.httpsCallable('getVerifiedXenditPaymentStatus');
    final result = await callable.call(<String, dynamic>{
      'paymentId': paymentId,
      'paymentType': paymentType,
    });
    final data = result.data;
    return data is Map ? (data['status'] ?? '').toString().toLowerCase() : '';
  }

  /// Loads the editable requirements for a booking form.
  ///
  /// `booking_requirements` is the preferred collection. `booking_forms` is
  /// also checked so existing, already-seeded parish records keep working
  /// while they are migrated to the preferred collection.
  Future<Map<String, dynamic>?> getBookingFormDefinition(String formKey) async {
    final key = formKey.trim();
    if (key.isEmpty) return null;

    try {
      for (final collectionName in const [
        'booking_requirements',
        'booking_forms',
      ]) {
        try {
          final collection = firestore.collection(collectionName);
          final doc = await collection.doc(key).get();
          if (doc.exists) return doc.data();

          for (final field in const [
            'formKey',
            'sacramentTypeKey',
            'bookingType',
            'sacramentType',
            'serviceType',
            'name',
            'title',
            'formName',
          ]) {
            final snapshot = await collection
                .where(field, isEqualTo: key)
                .limit(1)
                .get();
            if (snapshot.docs.isNotEmpty) return snapshot.docs.first.data();
          }

          // Older parish data may use a display name as its document ID or
          // store the key in a differently named field. Read the collection
          // and match normalized values so those records remain usable.
          final allForms = await collection.limit(100).get();
          for (final form in allForms.docs) {
            final data = form.data();
            final candidates = <Object?>[
              form.id,
              data['formKey'],
              data['sacramentTypeKey'],
              data['bookingType'],
              data['sacramentType'],
              data['serviceType'],
              data['name'],
              data['title'],
              data['formName'],
            ];
            if (candidates.any((value) =>
                _bookingFormKeysMatch(value?.toString() ?? '', key))) {
              return data;
            }
          }
        } catch (e) {
          debugPrint('Failed to check $collectionName/$key: $e');
        }
      }
      return null;
    } catch (e) {
      debugPrint('Failed to load booking form definition for $key: $e');
      return null;
    }
  }

  // Kept as a compatibility alias for callers that used the original name.
  Future<Map<String, dynamic>?> getBookingRequirements(String formKey) {
    return getBookingFormDefinition(formKey);
  }

  bool _bookingFormKeysMatch(String candidate, String requestedKey) {
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final candidateKey = normalize(candidate);
    final requested = normalize(requestedKey);
    if (candidateKey == requested) return true;
    if (candidateKey == 'req$requested' ||
        candidateKey == 'req${requested}s' ||
        candidateKey == 'requirement$requested') {
      return true;
    }

    const aliases = <String, List<String>>{
      'baptism': ['binyag'],
      'confirmation': ['kumpil'],
      'wedding': ['kasal', 'matrimony'],
      'funeral': ['funeralmass', 'misaparasayumao'],
      'houseblessing': ['basbasngbahay'],
      'anointing': ['anointingofthesick', 'pagpapahidsamaysakit'],
      'massintention': ['intensyonngmisa'],
      'firstcommunion': ['unangkomunyon'],
    };
    return aliases[requested]?.map(normalize).contains(candidateKey) ?? false;
  }

  Future<String> askParishAssistant({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final callable = functions.httpsCallable('askParishAssistant');
    final result = await callable.call(<String, dynamic>{
      'message': message.trim(),
      'history': history
          .map(
            (entry) => <String, String>{
              'role': entry['role'] ?? '',
              'content': entry['content'] ?? '',
            },
          )
          .toList(growable: false),
    });

    final data = result.data;
    if (data is Map && data['reply'] is String) {
      return (data['reply'] as String).trim();
    }

    throw Exception('AI assistant returned an invalid response.');
  }

  Future<SchedulingConflictResult> checkSchedulingConflictWithFunction({
    required String sacramentType,
    required String date,
    required String time,
    String bookingId = '',
  }) async {
    final typeKey = _canonicalSacramentTypeKey(sacramentType);
    if (typeKey != 'mass_intention' &&
        await isMassScheduleTime(date: date, time: time)) {
      return SchedulingConflictResult.conflict(
        bookingId: '',
        sacramentType: sacramentType,
        userName: 'Mass Schedule',
        date: date,
        time: time,
        message:
            'You cannot book during Mass schedule. Please choose another time.',
      );
    }

    try {
      final callable = functions.httpsCallable('checkSchedulingConflict');
      final result = await callable.call(<String, dynamic>{
        'sacramentType': sacramentType,
        'date': date,
        'time': time,
        if (bookingId.trim().isNotEmpty) 'bookingId': bookingId.trim(),
      });

      final data = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : <String, dynamic>{};
      final hasConflict = data['hasConflict'] == true;

      if (hasConflict) {
        return SchedulingConflictResult.conflict(
          bookingId: '',
          sacramentType: sacramentType,
          userName: 'Another Parishioner',
          date: date,
          time: time,
          message:
              (data['reason'] ??
                      'The selected date and time conflicts with another approved booking.')
                  .toString(),
        );
      }
    } catch (e) {
      debugPrint(
        'FirebaseService: Cloud Function conflict check failed, using local fallback: $e',
      );
    }

    try {
      final availability = await getBookingAvailability(
        date: date,
        time: time,
        sacramentType: sacramentType,
      );
      final status = availability['status']?.toString() ?? '';
      final overlapCount =
          (availability['overlapCount'] as num?)?.toInt() ?? 0;
      final periodBookedCount =
          (availability['periodBookedCount'] as num?)?.toInt() ?? 0;
      if (status == 'fully_booked' ||
          overlapCount > 0 ||
          periodBookedCount > 0) {
        return SchedulingConflictResult.conflict(
          bookingId: '',
          sacramentType: sacramentType,
          userName: 'Another Parishioner',
          date: date,
          time: time,
          message:
              'The selected date and time conflicts with another approved booking.',
        );
      }
    } catch (e) {
      debugPrint(
        'FirebaseService: Availability function check failed, using local fallback: $e',
      );
    }

    return SchedulingConflictResult.noConflict();
  }

  Future<void> submitBooking({
    required String sacramentType,
    required Map<String, dynamic> details,
    bool checkConflict = true,
  }) async {
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be signed in to submit a booking');
    }

    final now = Timestamp.now();
    final typeKey = _canonicalSacramentTypeKey(sacramentType);
    final date = _extractScheduleDateFromDetails(details, typeKey);
    final time = _extractScheduleTimeFromDetails(details, typeKey);

    debugPrint('[SUBMIT BOOKING] Extracted date: "$date", time: "$time"');
    debugPrint(
      '[SUBMIT BOOKING] Sacrament type: "$sacramentType" (key: "$typeKey")',
    );

    // Validate that date and time are provided for booking submission
    if (date.isEmpty) {
      debugPrint('[SUBMIT BOOKING] ERROR: Date is empty!');
      throw Exception('Date is required to submit a booking.');
    }

    if (time.isEmpty) {
      debugPrint('[SUBMIT BOOKING] ERROR: Time is empty!');
      throw Exception('Time is required to submit a booking.');
    }

    if (typeKey != 'mass_intention' &&
        await isMassScheduleTime(date: date, time: time)) {
      throw Exception(
        'You cannot book during Mass schedule. Please choose another time.',
      );
    }

    // Check for scheduling conflicts before submitting
    if (checkConflict) {
      debugPrint(
        '[SUBMIT BOOKING] Checking for conflicts (checkConflict=$checkConflict)',
      );
      final conflictResult = await checkSchedulingConflictWithFunction(
        sacramentType: sacramentType,
        date: date,
        time: time,
      );

      debugPrint(
        '[SUBMIT BOOKING] Conflict check result: hasConflict=${conflictResult.hasConflict}',
      );

      if (conflictResult.hasConflict) {
        debugPrint(
          'FirebaseService: Booking rejected due to scheduling conflict',
        );
        throw Exception(
          'This schedule is already occupied. ${conflictResult.errorMessage} Please choose another available schedule.',
        );
      }
    } else {
      debugPrint(
        '[SUBMIT BOOKING] Skipping conflict check (checkConflict=false)',
      );
    }

    // For Mass Intention, validate against official Mass Schedule
    if (typeKey == 'mass_intention') {
      if (date.isEmpty || time.isEmpty) {
        throw Exception(
          'Mass Intention requires both date and time to be specified.',
        );
      }

      final isValidMassSchedule = await SchedulingConflictService.instance
          .validateMassIntentionSchedule(date: date, time: time);

      if (!isValidMassSchedule) {
        debugPrint(
          'FirebaseService: Mass Intention schedule validation did not find a matching schedule for $date at $time. Allowing direct form submission because the Mass Intention form limits choices to database-loaded schedules.',
        );
      }
    }

    // Generate structured ID for booking
    final structuredId = await generateStructuredId('booking');

    final document = <String, dynamic>{
      'structuredId': structuredId, // New structured ID
      'userId': currentUser.uid,
      'userName': currentUser.displayName ?? 'Guest',
      'userEmail': currentUser.email ?? '',
      'sacramentType': sacramentType,
      'sacramentTypeKey': typeKey,
      'date': date,
      'time': time,
      'details': details,
      'submittedAt': now,
      'updatedAt': now,
      'status': 'pending',
      'assignedPriest': '',
      'adminNotes': '',
    };

    // Use structured ID as document ID
    await firestore.collection('bookings').doc(structuredId).set(document);

    debugPrint(
      'FirebaseService: Booking submitted successfully - $structuredId',
    );
  }

  Future<void> submitSacramentRequest({
    required String sacramentType,
    required Map<String, dynamic> details,
  }) async {
    await submitBooking(sacramentType: sacramentType, details: details);
  }

  /// Check for scheduling conflicts before submitting a booking
  /// This method allows form screens to validate availability before submission
  ///
  /// Returns: [SchedulingConflictResult] with conflict information
  Future<SchedulingConflictResult> checkBookingConflict({
    required String sacramentType,
    required Map<String, dynamic> details,
  }) async {
    final typeKey = _canonicalSacramentTypeKey(sacramentType);
    final date = _extractScheduleDateFromDetails(details, typeKey);
    final time = _extractScheduleTimeFromDetails(details, typeKey);

    return await checkSchedulingConflictWithFunction(
      sacramentType: sacramentType,
      date: date,
      time: time,
    );
  }

  /// Validate Mass Intention schedule
  /// Checks if the selected date and time match official Mass schedules
  ///
  /// Returns: true if valid Mass schedule, false otherwise
  Future<bool> validateMassIntentionSchedule({
    required String date,
    required String time,
  }) async {
    return await SchedulingConflictService.instance
        .validateMassIntentionSchedule(date: date, time: time);
  }

  Future<bool> isMassScheduleTime({
    required String date,
    required String time,
  }) async {
    return await SchedulingConflictService.instance.isMassScheduleTime(
      date: date,
      time: time,
    );
  }

  /// Get available time slots for a specific date
  /// Useful for calendar/date picker UI
  ///
  /// Parameters:
  /// - [date]: The date to check availability for (YYYY-MM-DD format)
  /// - [allPossibleTimeSlots]: List of all available time slots to check against
  ///
  /// Returns: List of available (non-booked) time slots
  Future<List<String>> getAvailableTimeSlots({
    required String date,
    required List<String> allPossibleTimeSlots,
  }) async {
    return await SchedulingConflictService.instance.getAvailableTimeSlots(
      date,
      allPossibleTimeSlots,
    );
  }

  /// Get all bookings for a specific date
  /// Useful for displaying booked times on a calendar
  Future<List<BookingRecord>> getBookingsForDate(String date) async {
    return await SchedulingConflictService.instance.getBookingsForDate(date);
  }

  /// Count active (approved or pending) bookings for a specific date
  /// Returns count of bookings with status 'approved', 'pending', 'confirmed', 'paid', or 'accepted'
  Future<int> countActiveBookingsForDate(String date) async {
    return await SchedulingConflictService.instance.countActiveBookingsForDate(date);
  }

  Future<String> getBookedDatesContext() async {
    try {
      final newSnap = await firestore
          .collection('bookings')
          .where(
            'status',
            whereIn: [
              'pending',
              'approved',
              'accepted',
              'confirmed',
              'paid',
              'Pending',
              'Approved',
              'Accepted',
              'Confirmed',
              'Paid',
            ],
          )
          .get();
      final oldSnap = await firestore.collection('sacrament_requests').get();
      final List<String> bookedList = [];

      for (var doc in [...newSnap.docs, ...oldSnap.docs]) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';
        // Only include active bookings
        if (status == 'cancelled' || status == 'rejected') continue;

        final type = data['sacramentType'] as String? ?? 'Unknown Sacrament';
        final details = data['details'] as Map<String, dynamic>? ?? {};
        final fields = details['fields'] as Map<String, dynamic>? ?? {};

        // Scan dynamic fields for dates
        String dateStr = '';
        fields.forEach((key, value) {
          final k = key.toLowerCase();
          if ((k.contains('date') || k.contains('petsa')) &&
              value.toString().contains('-')) {
            dateStr = value.toString();
          }
        });

        if (dateStr.isNotEmpty) {
          bookedList.add("- $dateStr : $type ($status)");
        }
      }

      if (bookedList.isEmpty) {
        return "No sacraments are currently booked or pending. All dates are generally available.";
      }

      // Sort the list so they are chronological in string format (since format is YYYY-MM-DD)
      bookedList.sort();
      return bookedList.join("\n");
    } catch (e) {
      debugPrint('Error getting booked dates context: $e');
      return "Unable to fetch current bookings at this time.";
    }
  }

  Future<bool> isMassScheduleSlotTaken({
    required String date,
    required String time,
  }) async {
    final newSnap = await firestore
        .collection('bookings')
        .where(
          'status',
          whereIn: [
            'pending',
            'approved',
            'accepted',
            'confirmed',
            'paid',
            'Pending',
            'Approved',
            'Accepted',
            'Confirmed',
            'Paid',
          ],
        )
        .get();
    final oldSnap = await firestore.collection('sacrament_requests').get();
    for (final doc in [...newSnap.docs, ...oldSnap.docs]) {
      final data = doc.data();
      final status = data['status'] as String? ?? 'pending';
      if (status == 'cancelled' || status == 'rejected') continue;

      final details = data['details'] as Map<String, dynamic>? ?? {};
      final fields = details['fields'] as Map<String, dynamic>? ?? {};

      final dateVal =
          (fields['Date of Mass (Petsa ng Misa)'] ?? fields['Date of Mass'])
              ?.toString()
              .trim();
      final timeVal =
          (fields['Time of Mass (Oras ng Misa)'] ?? fields['Time of Mass'])
              ?.toString()
              .trim();

      if (dateVal == null || timeVal == null) continue;
      if (dateVal == date.trim() && timeVal == time.trim()) {
        return true;
      }
    }
    return false;
  }

  Future<bool> isAnyScheduleSlotTaken({
    required String date,
    required String time,
    required String sacramentType,
  }) async {
    final canonicalType = _canonicalSacramentTypeKey(sacramentType);
    if (canonicalType == 'mass_intention') {
      return false;
    }

    int? parseTimeToMinutes(String value) {
      final raw = value
          .replaceAll('\u00A0', ' ')
          .replaceAll('\u202F', ' ')
          .trim();
      if (raw.isEmpty) return null;
      final extracted = RegExp(
        r'\b(\d{1,2}(?::\d{2})?[\s\u00A0\u202F]*(?:[AaPp][Mm])?)\b',
      ).firstMatch(raw)?.group(1);
      if (extracted == null) return null;

      final match = RegExp(
        r'^(\d{1,2})(?::(\d{2}))?[\s\u00A0\u202F]*([AaPp][Mm])?$',
      ).firstMatch(extracted.trim());
      if (match == null) return null;

      int h = int.tryParse(match.group(1) ?? '') ?? -1;
      final int m = int.tryParse(match.group(2) ?? '00') ?? -1;
      if (h < 0 || m < 0 || m > 59) return null;

      final ampm = (match.group(3) ?? '').toLowerCase();
      if (ampm.isNotEmpty) {
        if (h < 1 || h > 12) return null;
        if (ampm == 'am') {
          h = h == 12 ? 0 : h;
        } else if (ampm == 'pm') {
          h = h == 12 ? 12 : h + 12;
        }
      } else {
        if (h > 23) return null;
        if (h >= 1 && h <= 5) {
          h += 12;
        }
      }

      return h * 60 + m;
    }

    String schedulePeriod(int minutes) => minutes < 12 * 60 ? 'AM' : 'PM';

    final requestedMinutes = parseTimeToMinutes(time);
    if (requestedMinutes == null) {
      return false;
    }

    // Define sacraments that should block same-time bookings
    final timeBlockingSacraments = {
      'Binyag',
      'Baptism',
      'Kasal',
      'Wedding',
      'Kumpil',
      'Confirmation',
      'Misa para sa Yumao',
      'Funeral Mass',
      'Palista sa House Blessing',
      'House Blessing',
      'Palista sa Pagpapahid ng Langis sa May Sakit',
      'Anointing of the Sick',
    };

    final shouldBlockSameTime = timeBlockingSacraments.contains(
      sacramentType.trim(),
    );

    final requestedPeriod = schedulePeriod(requestedMinutes);
    final blockWindowMinutes = shouldBlockSameTime ? 60 : 240;

    final oldSnapshot = await firestore
        .collection('sacrament_requests')
        .where(
          'status',
          whereIn: [
            'approved',
            'accepted',
            'confirmed',
            'paid',
            'Approved',
            'Accepted',
            'Confirmed',
            'Paid',
          ],
        )
        .get();
    final newSnapshot = await firestore
        .collection('bookings')
        .where(
          'status',
          whereIn: [
            'approved',
            'accepted',
            'confirmed',
            'paid',
            'Approved',
            'Accepted',
            'Confirmed',
            'Paid',
          ],
        )
        .get();

    for (final doc in [...oldSnapshot.docs, ...newSnapshot.docs]) {
      final data = doc.data();
      final status = (data['status'] as String? ?? 'pending').toLowerCase();
      if (status == 'cancelled' || status == 'rejected') continue;

      final rowType = (data['sacramentType'] ?? '').toString().trim();
      final rowTypeKey = _canonicalSacramentTypeKey(
        (data['sacramentTypeKey'] ?? rowType).toString(),
      );

      // Same-day AM/PM limits are per sacrament type.
      if (shouldBlockSameTime) {
        if (rowTypeKey != canonicalType) {
          continue;
        }
      } else {
        if (rowType.isNotEmpty && rowType != sacramentType.trim()) {
          continue;
        }
      }

      final details = data['details'] as Map<String, dynamic>? ?? {};
      final fields = details['fields'] as Map<String, dynamic>? ?? {};

      String foundDate = '';
      String foundTime = '';

      fields.forEach((k, v) {
        final key = k.toString().toLowerCase();
        final val = (v ?? '').toString().trim();
        if (foundDate.isEmpty &&
            (key.contains('date') || key.contains('petsa')) &&
            val.contains('-')) {
          foundDate = val;
        }
        if (foundTime.isEmpty &&
            (key.contains('time') || key.contains('oras')) &&
            val.contains(':')) {
          foundTime = val;
        }
      });

      if (foundDate.isNotEmpty &&
          foundTime.isNotEmpty &&
          foundDate == date.trim()) {
        final foundMinutes = parseTimeToMinutes(foundTime);
        if (foundMinutes == null) continue;
        final diff = (foundMinutes - requestedMinutes).abs();
        final sameServicePeriodIsTaken =
            shouldBlockSameTime &&
            schedulePeriod(foundMinutes) == requestedPeriod;
        if (diff < blockWindowMinutes || sameServicePeriodIsTaken) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if a date is blocked by parish booking rules.
  Future<bool> isDateBlockedByRecentBookings({required String date}) async {
    try {
      final parsedDate = DateTime.parse(date);
      final requestedDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );
      var today = DateTime.now();
      today = DateTime(
        today.year,
        today.month,
        today.day,
      ); // Normalize to start of day

      final earliestAllowedDate = today.add(const Duration(days: 2));
      return requestedDate.isBefore(earliestAllowedDate) ||
          requestedDate.weekday == DateTime.monday;
    } catch (e) {
      return true;
    }
  }

  Future<void> requestPasswordResetOtp({required String email}) async {
    final callable = functions.httpsCallable('requestPasswordResetOtp');
    await callable.call(<String, dynamic>{'email': email.trim()});
  }

  Future<void> verifyPasswordResetOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final callable = functions.httpsCallable(
      'verifyPasswordResetOtpAndResetPassword',
    );
    await callable.call(<String, dynamic>{
      'email': email.trim(),
      'otp': otp.trim(),
      'newPassword': newPassword,
    });
  }

  /// Get parish profile data.
  ///
  /// The app normally reads `/parish_profile/main`, but it also falls back to
  /// any document in the root `parish_profile` collection or nested
  /// `parish_profile` subcollections if the document is stored elsewhere.
  Future<ParishProfile?> getParishProfile() async {
    try {
      debugPrint('Attempting to fetch parish_profile/main...');
      final primaryDoc = firestore.collection('parish_profile').doc('main');
      final primarySnapshot = await primaryDoc.get();
      if (primarySnapshot.exists) {
        debugPrint('Found parish_profile/main document.');
        return ParishProfile.fromFirestore(primarySnapshot);
      }

      debugPrint(
        'parish_profile/main not found. Checking root parish_profile collection...',
      );
      final fallbackRoot = await firestore
          .collection('parish_profile')
          .limit(10)
          .get();
      if (fallbackRoot.docs.isNotEmpty) {
        debugPrint(
          'Found parish_profile document(s) in root collection: ${fallbackRoot.docs.map((d) => d.id).toList()}',
        );
        return ParishProfile.fromFirestore(fallbackRoot.docs.first);
      }

      debugPrint(
        'No root-level parish_profile documents found. Checking collectionGroup(parish_profile)...',
      );
      try {
        final groupFallback = await firestore
            .collectionGroup('parish_profile')
            .limit(10)
            .get();
        if (groupFallback.docs.isNotEmpty) {
          debugPrint(
            'Found parish_profile document(s) in subcollections: ${groupFallback.docs.map((d) => d.reference.path).toList()}',
          );
          return ParishProfile.fromFirestore(groupFallback.docs.first);
        }
      } catch (groupError) {
        debugPrint('Parish profile collectionGroup query failed: $groupError');
      }

      debugPrint('No parish_profile document found in Firestore.');
      return null;
    } catch (e) {
      debugPrint('Error fetching parish profile: $e');
      return null;
    }
  }

  /// Return Firestore diagnostics for parish_profile access.
  Future<String> getParishProfileDebugInfo() async {
    try {
      final buffer = StringBuffer();

      final primaryDoc = firestore.collection('parish_profile').doc('main');
      final primarySnapshot = await primaryDoc.get();
      buffer.writeln(
        'Checked /parish_profile/main: exists=${primarySnapshot.exists}',
      );

      final rootCollection = await firestore
          .collection('parish_profile')
          .limit(20)
          .get();
      buffer.writeln(
        'Root parish_profile docs count=${rootCollection.docs.length}',
      );
      if (rootCollection.docs.isNotEmpty) {
        buffer.writeln(
          'Root doc IDs=${rootCollection.docs.map((d) => d.id).toList()}',
        );
      }

      try {
        final groupDocs = await firestore
            .collectionGroup('parish_profile')
            .limit(20)
            .get();
        buffer.writeln(
          'CollectionGroup parish_profile docs count=${groupDocs.docs.length}',
        );
        if (groupDocs.docs.isNotEmpty) {
          buffer.writeln(
            'CollectionGroup doc paths=${groupDocs.docs.map((d) => d.reference.path).toList()}',
          );
        }
      } catch (groupError) {
        buffer.writeln('CollectionGroup query failed: $groupError');
      }

      return buffer.toString();
    } catch (e) {
      return 'Debug info error: $e';
    }
  }

  /// Stream parish profile data for real-time updates
  Stream<ParishProfile?> getParishProfileStream() {
    final primaryDoc = firestore.collection('parish_profile').doc('main');
    return primaryDoc.snapshots().asyncMap((doc) async {
      if (doc.exists) {
        return ParishProfile.fromFirestore(doc);
      }

      final fallbackRoot = await firestore
          .collection('parish_profile')
          .limit(10)
          .get();
      if (fallbackRoot.docs.isNotEmpty) {
        return ParishProfile.fromFirestore(fallbackRoot.docs.first);
      }

      try {
        final groupFallback = await firestore
            .collectionGroup('parish_profile')
            .limit(10)
            .get();
        if (groupFallback.docs.isNotEmpty) {
          return ParishProfile.fromFirestore(groupFallback.docs.first);
        }
      } catch (groupError) {
        debugPrint('Parish profile group query failed: $groupError');
      }

      return null;
    });
  }
}
