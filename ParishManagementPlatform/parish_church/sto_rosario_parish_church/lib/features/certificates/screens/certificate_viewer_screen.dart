import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';

class CertificateViewerScreen extends StatefulWidget {
  final String title;
  final String requestId;

  const CertificateViewerScreen({super.key, required this.title, required this.requestId});

  @override
  State<CertificateViewerScreen> createState() => _CertificateViewerScreenState();
}

class _CertificateViewerScreenState extends State<CertificateViewerScreen> {
  static const _security = MethodChannel('parish/certificate_screen_security');
  late Future<_CertificateFile> _file;
  bool _secureSet = false;

  @override
  void initState() {
    super.initState();
    _enableProtection();
    _file = _load();
  }

  Future<void> _enableProtection() async {
    try {
      await _security.invokeMethod<bool>('setSecure', {'enabled': true});
      _secureSet = true;
    } on MissingPluginException {
      // Screenshot protection is unavailable on this platform.
    } on PlatformException {
      // Keep certificate viewing available if the platform rejects protection.
    }
  }

  Future<void> _disableProtection() async {
    if (!_secureSet) return;
    try {
      await _security.invokeMethod<bool>('setSecure', {'enabled': false});
    } on PlatformException {
      // The screen is closing; there is no platform-specific recovery action.
    }
  }

  Future<_CertificateFile> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Please sign in to view this certificate.');
    final token = await user.getIdToken();
    final projectId = Firebase.app().options.projectId;
    if (projectId == null || projectId.isEmpty) {
      throw Exception('Certificate viewing is not configured for this app.');
    }
    final uri = Uri.https(
      'asia-southeast1-$projectId.cloudfunctions.net',
      '/viewMyCertificateSoftCopy',
      {'requestId': widget.requestId},
    );
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 45));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      final detail = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      throw Exception(detail.isEmpty
          ? 'The certificate could not be opened.'
          : detail);
    }
    final bytes = Uint8List.fromList(response.bodyBytes);
    final isPdf = bytes.length >= 4 && String.fromCharCodes(bytes.take(4)) == '%PDF';
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    if (!isPdf && !contentType.startsWith('image/')) {
      throw Exception('This certificate file format is not supported.');
    }
    return _CertificateFile(bytes, isPdf);
  }

  @override
  void dispose() {
    _disableProtection();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        backgroundColor: const Color(0xFF202124),
        body: FutureBuilder<_CertificateFile>(
          future: _file,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white)),
                ),
              );
            }
            final file = snapshot.data!;
            if (!file.isPdf) {
              return InteractiveViewer(
                child: Center(child: Image.memory(file.bytes, fit: BoxFit.contain)),
              );
            }
            final controller = PdfController(document: PdfDocument.openData(file.bytes));
            return PdfView(controller: controller);
          },
        ),
      );
}

class _CertificateFile {
  final Uint8List bytes;
  final bool isPdf;
  const _CertificateFile(this.bytes, this.isPdf);
}
