import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../../../firebase_options.dart';

/// Document validation result for sacramental requirements
class DocumentValidationResult {
  final bool isValid;
  final List<String> missingFields;
  final List<String> invalidFields;
  final List<String> warnings;
  final double confidenceScore;
  final Map<String, dynamic> extractedData;
  final String? errorMessage;

  DocumentValidationResult({
    required this.isValid,
    required this.missingFields,
    required this.invalidFields,
    required this.warnings,
    required this.confidenceScore,
    required this.extractedData,
    this.errorMessage,
  });
}

class _DocumentOcrResult {
  final String text;
  final List<String> qualityIssues;
  final List<String> warnings;
  final double qualityScore;
  final Map<String, dynamic> qualityData;

  const _DocumentOcrResult({
    required this.text,
    required this.qualityIssues,
    required this.warnings,
    required this.qualityScore,
    required this.qualityData,
  });

  bool get hasBlockingQualityIssues => qualityIssues.isNotEmpty;
}

/// Validation rules for different sacrament types
class SacramentValidationRules {
  static const Map<String, List<String>> baptismRequirements = {
    'Birth Certificate': [
      'full_name',
      'date_of_birth',
      'place_of_birth',
      'parent_names',
    ],
    'Confirmation Certificate': [
      'full_name',
      'date_of_confirmation',
      'parish_name',
    ],
    'Marriage Certificate': [
      'full_name',
      'date_of_marriage',
      'spouse_name',
      'witness_names',
    ],
  };

  static const Map<String, List<String>> confirmationRequirements = {
    'Birth Certificate (Sertipiko ng Kapanganakan)': [
      'full_name',
      'date_of_birth',
      'place_of_birth',
      'parent_names',
    ],
    'Baptismal Certificate (Sertipiko ng Binyag)': [
      'full_name',
      'date_of_baptism',
      'place_of_baptism',
      'parish_name',
    ],
  };

  static const Map<String, List<String>> weddingRequirements = {
    'Birth Certificate (Groom)': ['full_name', 'date_of_birth'],
    'Birth Certificate (Bride)': ['full_name', 'date_of_birth'],
    'Confirmation Certificate': ['full_name', 'date_of_confirmation'],
    'CENOMAR': ['canonical_preparation', 'freedom_to_marry'],
    'Marriage Banns': ['publication_dates', 'parish_name'],
  };

  static const Map<String, List<String>> funeralRequirements = {
    'Death Certificate': ['full_name', 'date_of_death', 'cause_of_death'],
    'Burial Permit': ['permit_number', 'date_issued', 'cemetery_name'],
  };
}

/// Document type configuration for validation
class DocumentTypeConfig {
  final String displayName;
  final List<String> requiredKeywords;
  final List<String> alternativeKeywords;
  final String errorMessage;

  const DocumentTypeConfig({
    required this.displayName,
    required this.requiredKeywords,
    this.alternativeKeywords = const [],
    required this.errorMessage,
  });
}

/// Document type configurations
class DocumentTypes {
  static const Map<String, DocumentTypeConfig> configs = {
    'Birth Certificate (Sertipiko ng Kapanganakan)': DocumentTypeConfig(
      displayName: 'Birth Certificate',
      requiredKeywords: ['Certificate of Live Birth'],
      alternativeKeywords: [
        'Birth Certificate',
        'Certificate of Birth',
        'Sertipiko ng Kapanganakan',
        'Live Birth',
        'Philippine Statistics Authority',
        'PSA',
        'Local Civil Registrar',
        'Civil Registrar',
        'Republic of the Philippines',
      ],
      errorMessage:
          'Invalid document: The uploaded file does not match the required Birth Certificate format.',
    ),
    'Baptismal Certificate (Sertipiko ng Binyag)': DocumentTypeConfig(
      displayName: 'Baptismal Certificate',
      requiredKeywords: ['BAPTISMAL CERTIFICATE'],
      alternativeKeywords: [
        'Certificate of Baptism',
        'Baptism Certificate',
        'Certificate of Baptismal',
        'Sertipiko ng Binyag',
        'CERTIFICATE OF BAPTISM',
        'BAPTISM CERTIFICATE',
        'SERTIPIKO NG BINYAG',
        'PAROCHIAL SCHOOL',
        'PARISH',
        'DIOCESE',
      ],
      errorMessage:
          'Invalid document: The uploaded file does not match the required Baptismal Certificate format.',
    ),
    'Marriage Contract': DocumentTypeConfig(
      displayName: 'Marriage License / Marriage Contract',
      requiredKeywords: ['Marriage Contract', 'Certificate of Marriage'],
      alternativeKeywords: [
        'Marriage Certificate',
        'Contract of Marriage',
        'Marriage License',
        'License to Contract Marriage',
      ],
      errorMessage:
          'Invalid document: The uploaded file does not match the required Marriage License/Contract format.',
    ),
    'Death Certificate': DocumentTypeConfig(
      displayName: 'Death Certificate',
      requiredKeywords: ['Death Certificate', 'Certificate of Death'],
      alternativeKeywords: ['Certificate of Death', 'Death Certification'],
      errorMessage:
          'Invalid document: The uploaded file does not match the required Death Certificate format.',
    ),
    'Confirmation Certificate': DocumentTypeConfig(
      displayName: 'Confirmation Certificate',
      requiredKeywords: [
        'Confirmation Certificate',
        'Certificate of Confirmation',
      ],
      alternativeKeywords: [
        'Sertipiko ng Kumpil',
        'CONFIRMATION CERTIFICATE',
        'CERTIFICATE OF CONFIRMATION',
        'KUMPIL',
      ],
      errorMessage:
          'Invalid document: The uploaded file does not match the required Confirmation Certificate format.',
    ),
    'Certificate of No Marriage': DocumentTypeConfig(
      displayName: 'Certificate of No Marriage',
      requiredKeywords: [
        'Certificate of No Marriage',
        'CENOMAR',
        'CERTIFICATE OF NO MARRIAGE RECORD',
      ],
      alternativeKeywords: [
        'No Record of Marriage',
        'No Marriage Record',
        'Negative Record of Marriage',
      ],
      errorMessage:
          'Invalid document: The uploaded file does not match the required CENOMAR format.',
    ),
    'Marriage Banns': DocumentTypeConfig(
      displayName: 'Marriage Banns',
      requiredKeywords: [
        'Marriage Banns',
        'Publication of Banns',
        'BANNS OF MARRIAGE',
      ],
      alternativeKeywords: [
        'Edict of Marriage',
        'Canonical Banns',
        'Pahayag ng Kasal',
      ],
      errorMessage:
          'Invalid document: The uploaded file does not match the required Marriage Banns format.',
    ),
    'Burial Permit': DocumentTypeConfig(
      displayName: 'Burial Permit',
      requiredKeywords: ['Burial Permit'],
      alternativeKeywords: [
        'Permit to Bury',
        'Libing',
        'Pahintulot sa Libing',
        'Cemetery',
        'Interment',
      ],
      errorMessage:
          'Invalid document: The uploaded file does not match the required Burial Permit format.',
    ),
    '2x2 Photo': DocumentTypeConfig(
      displayName: '2x2 Photo',
      requiredKeywords: [], // Image-only, no OCR text validation
      alternativeKeywords: [],
      errorMessage:
          'Invalid file: Please upload a valid 2x2 photo (JPG, PNG) under 10MB.',
    ),
    'Wedding Invitation': DocumentTypeConfig(
      displayName: 'Wedding Invitation',
      requiredKeywords: [], // Image-only, no OCR text validation
      alternativeKeywords: [],
      errorMessage:
          'Invalid file: Please upload a valid wedding invitation image (JPG, PNG) under 10MB.',
    ),
  };
}

/// AI-powered document validation service
class DocumentValidationService {
  /// Validate document using AI/OCR and document-specific validation
  static Future<DocumentValidationResult> validateDocument({
    required PlatformFile documentFile,
    required String sacramentType,
    required String requirementType,
  }) async {
    try {
      print('DEBUG: Starting document validation process');
      print('DEBUG: Requirement type: $requirementType');

      // Step 1: Extract text using OCR
      final ocrResult = await _extractTextFromDocument(documentFile);
      final extractedText = ocrResult.text;
      print('DEBUG: Extracted text from document: $extractedText');

      if (ocrResult.hasBlockingQualityIssues) {
        print('DEBUG: Blocking document due to image quality issues');
        print('DEBUG: Quality issues: ${ocrResult.qualityIssues}');

        final hasBlurIssue = ocrResult.qualityIssues.contains(
          'image_blurry_or_unreadable',
        );
        final hasCropIssue = ocrResult.qualityIssues.contains(
          'document_cropped',
        );
        final hasResolutionIssue = ocrResult.qualityIssues.contains(
          'image_resolution_too_low',
        );
        final hasReadabilityIssue = ocrResult.qualityIssues.contains(
          'insufficient_readable_text',
        );

        return DocumentValidationResult(
          isValid: false,
          missingFields: ['clear_uncropped_document'],
          invalidFields: ocrResult.qualityIssues,
          warnings: ocrResult.warnings,
          confidenceScore: ocrResult.qualityScore,
          extractedData: {
            'validation_method': 'ocr_quality_gate',
            ...ocrResult.qualityData,
          },
          errorMessage: hasResolutionIssue
              ? 'Document validation failed: The image resolution is too low. Please upload a clearer, higher-resolution photo or scan.'
              : hasReadabilityIssue
              ? 'Document validation failed: The document does not contain enough readable text. Please upload a clear, complete document.'
              : hasBlurIssue && hasCropIssue
              ? 'Document validation failed: The image appears blurry and cropped. Please upload a clear, complete photo or scan of the entire document.'
              : hasBlurIssue
              ? 'Document validation failed: The image appears blurry or unreadable. Please upload a clearer photo or scan.'
              : hasCropIssue
              ? 'Document validation failed: The document appears cropped. Please upload the full document with all edges visible.'
              : 'Document validation failed: Please upload a clear, complete document.',
        );
      }

      if (extractedText.isEmpty) {
        print('DEBUG: OCR failed - extractedText is empty');
        print('DEBUG: Using fallback validation with basic checks');

        // BASIC FALLBACK VALIDATION - Check file properties
        final isValidFile = _validateFileBasics(documentFile);

        if (isValidFile) {
          // Valid file type/size but OCR failed - LOW confidence for random images
          return DocumentValidationResult(
            isValid: false, // Mark as invalid since OCR couldn't extract text
            missingFields: ['extracted_text'],
            invalidFields: ['ocr_failed'],
            warnings: [
              'Could not extract text from document. Please ensure the document is clear and readable.',
              'Random images or photos without text will be rejected.',
            ],
            confidenceScore: 10.0, // Very low confidence - below 30% threshold
            extractedData: {
              'validation_method': 'fallback_basic',
              ...ocrResult.qualityData,
            },
            errorMessage:
                'Document validation failed: Unable to extract readable text. Please upload a clear, readable document.',
          );
        } else {
          // Invalid file - block upload
          return DocumentValidationResult(
            isValid: false,
            missingFields: ['valid_file_type'],
            invalidFields: ['file_format'],
            warnings: ['File type or size not suitable for document upload'],
            confidenceScore: 0.0,
            extractedData: {
              'validation_method': 'fallback_rejected',
              ...ocrResult.qualityData,
            },
            errorMessage:
                'Invalid document: Please upload a valid image file (JPG, PNG, PDF) under 10MB.',
          );
        }
      }

      // Check if extracted text is substantial enough
      if (extractedText.length < 5) {
        print(
          'DEBUG: Insufficient text in document - length: ${extractedText.length}',
        );
        print('DEBUG: Blocking upload - too little text for a document');
        return DocumentValidationResult(
          isValid: false,
          missingFields: ['sufficient_content'],
          invalidFields: ['document_readability'],
          warnings: ['Document contains insufficient readable text'],
          confidenceScore: 15.0,
          extractedData: {},
          errorMessage:
              'Invalid document: Please ensure you are uploading a clear, readable document.',
        );
      }

      // Step 2: Document-specific validation using switch-case
      final documentTypeResult = _validateDocumentType(
        extractedText,
        requirementType,
      );

      if (!documentTypeResult.isValid) {
        return documentTypeResult;
      }

      final structuredData = await _extractStructuredData(
        extractedText,
        sacramentType,
        requirementType,
      );

      // Step 3: Check if this is a template-based validation (baptism certificate)
      if (documentTypeResult.extractedData['validation_method'] ==
          'exact_template') {
        print(
          'DEBUG: Using template validation result - skipping sacrament field validation',
        );

        // Return template validation result with structured data
        return DocumentValidationResult(
          isValid: documentTypeResult.isValid,
          missingFields: documentTypeResult.missingFields,
          invalidFields: documentTypeResult.invalidFields,
          warnings: documentTypeResult.warnings,
          confidenceScore: documentTypeResult.confidenceScore,
          extractedData: {
            ...structuredData,
            ...documentTypeResult.extractedData,
          },
        );
      }

      return DocumentValidationResult(
        isValid: true,
        missingFields: [],
        invalidFields: [],
        warnings: [
          ...documentTypeResult.warnings,
          ...ocrResult.warnings,
        ],
        confidenceScore: documentTypeResult.confidenceScore,
        extractedData: {
          ...structuredData,
          ...documentTypeResult.extractedData,
          ...ocrResult.qualityData,
        },
      );
    } catch (e) {
      return DocumentValidationResult(
        isValid: false,
        missingFields: [],
        invalidFields: [],
        warnings: [],
        confidenceScore: 0.0,
        extractedData: {},
        errorMessage: 'Validation failed: ${e.toString()}',
      );
    }
  }

  /// Validate document type using specific keyword requirements
  static DocumentValidationResult _validateDocumentType(
    String extractedText,
    String requirementType,
  ) {
    print('DEBUG: Validating document type: $requirementType');

    // Get document configuration
    final config = DocumentTypes.configs[requirementType];

    if (config == null) {
      print(
        'DEBUG: Unknown document type: $requirementType - trying fallback matching',
      );

      // Try to find a matching document type by checking if requirementType contains known keywords
      DocumentTypeConfig? fallbackConfig;
      String? matchedType;

      if (requirementType.toLowerCase().contains('baptism')) {
        fallbackConfig = DocumentTypes
            .configs['Baptismal Certificate (Sertipiko ng Binyag)'];
        matchedType = 'Baptismal Certificate';
      } else if (requirementType.toLowerCase().contains('birth')) {
        fallbackConfig = DocumentTypes
            .configs['Birth Certificate (Sertipiko ng Kapanganakan)'];
        matchedType = 'Birth Certificate';
      } else if (requirementType.toLowerCase().contains('marriage license') ||
          requirementType.toLowerCase().contains('marriage contract')) {
        fallbackConfig = DocumentTypes.configs['Marriage Contract'];
        matchedType = 'Marriage Contract';
      } else if (requirementType.toLowerCase().contains('marriage banns')) {
        fallbackConfig = DocumentTypes.configs['Marriage Banns'];
        matchedType = 'Marriage Banns';
      } else if (requirementType.toLowerCase().contains('burial') ||
          requirementType.toLowerCase().contains('libing')) {
        fallbackConfig = DocumentTypes.configs['Burial Permit'];
        matchedType = 'Burial Permit';
      } else if (requirementType.toLowerCase().contains('death')) {
        fallbackConfig = DocumentTypes.configs['Death Certificate'];
        matchedType = 'Death Certificate';
      } else if (requirementType.toLowerCase().contains('confirmation')) {
        fallbackConfig = DocumentTypes.configs['Confirmation Certificate'];
        matchedType = 'Confirmation Certificate';
      } else if (requirementType.toLowerCase().contains('cenomar') ||
          requirementType.toLowerCase().contains(
            'certificate of no marriage',
          )) {
        fallbackConfig = DocumentTypes.configs['Certificate of No Marriage'];
        matchedType = 'Certificate of No Marriage';
      } else if (requirementType.toLowerCase().contains('2x2') ||
          requirementType.toLowerCase().contains('photo')) {
        fallbackConfig = DocumentTypes.configs['2x2 Photo'];
        matchedType = '2x2 Photo';
      } else if (requirementType.toLowerCase().contains('invitation')) {
        fallbackConfig = DocumentTypes.configs['Wedding Invitation'];
        matchedType = 'Wedding Invitation';
      }

      if (fallbackConfig != null) {
        print('DEBUG: Using fallback configuration for: $matchedType');
        return _validateDocumentWithConfig(extractedText, fallbackConfig);
      }

      print('DEBUG: No matching document type found for: $requirementType');
      return DocumentValidationResult(
        isValid: false,
        missingFields: ['document_type'],
        invalidFields: ['unknown_type'],
        warnings: ['Unknown document type: $requirementType'],
        confidenceScore: 0.0,
        extractedData: {},
        errorMessage: 'Invalid document: Unknown document type specified.',
      );
    }

    // Use the existing validation logic
    return _validateDocumentWithConfig(extractedText, config);
  }

  /// Helper method to validate document with a specific configuration
  static DocumentValidationResult _validateDocumentWithConfig(
    String extractedText,
    DocumentTypeConfig config,
  ) {
    print('DEBUG: Validating with config: ${config.displayName}');

    // Special template validation for baptism certificates
    if (config.displayName == 'Baptismal Certificate') {
      return _validateBaptismalCertificateTemplate(extractedText, config);
    }

    // Image-only uploads (no OCR text validation required)
    // Only allow specific image-only document types like photos
    if (config.requiredKeywords.isEmpty && config.alternativeKeywords.isEmpty) {
      print(
        'DEBUG: Image-only upload for ${config.displayName} - checking if allowed',
      );

      // Only allow specific image-only types like 2x2 Photo or Wedding Invitation
      final allowedImageOnlyTypes = ['2x2 Photo', 'Wedding Invitation'];

      if (allowedImageOnlyTypes.contains(config.displayName)) {
        return DocumentValidationResult(
          isValid: true,
          missingFields: [],
          invalidFields: [],
          warnings: [],
          confidenceScore: 75.0, // High confidence for allowed image-only types
          extractedData: {
            'document_type': config.displayName,
            'validation_method': 'image_only_allowed',
          },
        );
      } else {
        // Block other image-only uploads with low confidence
        return DocumentValidationResult(
          isValid: false,
          missingFields: ['document_content'],
          invalidFields: ['random_image'],
          warnings: [
            'This document type requires readable text content.',
            'Random images without proper document content will be rejected.',
          ],
          confidenceScore: 15.0, // Low confidence - below 30% threshold
          extractedData: {
            'document_type': config.displayName,
            'validation_method': 'image_only_blocked',
          },
          errorMessage:
              'Invalid document: This type requires readable text content. Please upload a proper document.',
        );
      }
    }

    // Check for required keywords
    final lowerCaseText = extractedText.toLowerCase();
    bool hasRequiredKeyword = false;
    String foundKeyword = '';

    // Check primary required keywords
    for (final keyword in config.requiredKeywords) {
      if (lowerCaseText.contains(keyword.toLowerCase())) {
        hasRequiredKeyword = true;
        foundKeyword = keyword;
        break;
      }
    }

    // If not found in primary keywords, check alternative keywords
    if (!hasRequiredKeyword) {
      for (final keyword in config.alternativeKeywords) {
        if (lowerCaseText.contains(keyword.toLowerCase())) {
          hasRequiredKeyword = true;
          foundKeyword = keyword;
          break;
        }
      }
    }

    print('DEBUG: Required keywords: ${config.requiredKeywords}');
    print('DEBUG: Alternative keywords: ${config.alternativeKeywords}');
    print('DEBUG: Found required keyword: $foundKeyword');
    print('DEBUG: Has required keyword: $hasRequiredKeyword');

    if (!hasRequiredKeyword) {
      return DocumentValidationResult(
        isValid: false,
        missingFields: ['required_keyword'],
        invalidFields: ['document_format'],
        warnings: [
          'Document does not contain required keywords for ${config.displayName}',
        ],
        confidenceScore: 20.0, // Below 30% threshold
        extractedData: {},
        errorMessage: config.errorMessage,
      );
    }

    // Document is valid - give high confidence
    return DocumentValidationResult(
      isValid: true,
      missingFields: [],
      invalidFields: [],
      warnings: [],
      confidenceScore: 85.0, // High confidence for correct document type
      extractedData: {
        'document_type': config.displayName,
        'matched_keyword': foundKeyword,
      },
      errorMessage: null,
    );
  }

  /// Special validation for Philippine baptism certificate templates
  static DocumentValidationResult _validateBaptismalCertificateTemplate(
    String extractedText,
    DocumentTypeConfig config,
  ) {
    print('DEBUG: Validating baptism certificate template');

    final upperText = extractedText.toUpperCase();
    final lowerText = extractedText.toLowerCase();

    // EXACT TEMPLATE PHRASES from user's format
    final templatePhrases = [
      'CERTIFICATE OF BAPTISM',
      'THIS IS TO CERTIFY',
      'CHILD OF',
      'BORN IN',
      'WAS SOLEMNLY BAPTIZED ON',
      'ACCORDING TO THE RITE OF THE ROMAN CATHOLIC CHURCH',
      'BY THE REVEREND',
      'THE SPONSORS BEING',
    ];

    // Check for exact template phrases
    int templatePhraseCount = 0;
    List<String> foundPhrases = [];

    for (final phrase in templatePhrases) {
      if (upperText.contains(phrase.toUpperCase())) {
        templatePhraseCount++;
        foundPhrases.add(phrase);
      }
    }

    // Check for baptism certificate title variations
    final baptismIndicators = [
      'CERTIFICATE OF BAPTISM',
      'BAPTISMAL CERTIFICATE',
      'BAPTISM CERTIFICATE',
      'SERTIPIKO NG BINYAG',
    ];

    bool hasBaptismIndicator = false;
    String foundIndicator = '';

    for (final indicator in baptismIndicators) {
      if (upperText.contains(indicator)) {
        hasBaptismIndicator = true;
        foundIndicator = indicator;
        break;
      }
    }

    // Check for Catholic Church context
    final churchIndicators = [
      'ROMAN CATHOLIC CHURCH',
      'CATHOLIC',
      'CHURCH',
      'REVEREND',
      'PARISH',
      'DIOCESE',
    ];

    bool hasChurchIndicator = false;
    for (final indicator in churchIndicators) {
      if (upperText.contains(indicator)) {
        hasChurchIndicator = true;
        break;
      }
    }

    // Check for baptism-related terms
    final baptismTerms = [
      'BAPTIZED',
      'BAPTISM',
      'BAPTISMAL',
      'BINYAG',
      'BININYAGAN',
      'SACRAMENT',
      'SPONSORS',
      'GODPARENTS',
      'NINONG',
      'NINANG',
    ];

    int baptismTermCount = 0;
    for (final term in baptismTerms) {
      if (lowerText.contains(term.toLowerCase())) {
        baptismTermCount++;
      }
    }

    print('DEBUG: Template phrases found: $templatePhraseCount/9');
    print('DEBUG: Found phrases: $foundPhrases');
    print('DEBUG: Baptism indicator: $foundIndicator');
    print('DEBUG: Church indicator: $hasChurchIndicator');
    print('DEBUG: Baptism terms count: $baptismTermCount');

    // EXACT TEMPLATE VALIDATION LOGIC
    bool isValid = false;
    double confidenceScore = 0.0;
    List<String> warnings = [];

    if (templatePhraseCount >= 5) {
      // PERFECT MATCH - Most template phrases found
      isValid = true;
      confidenceScore = 100.0;
    } else if (templatePhraseCount >= 3 && hasBaptismIndicator) {
      // STRONG MATCH - Several template phrases + baptism indicator
      isValid = true;
      confidenceScore = 95.0;
    } else if (hasBaptismIndicator && templatePhraseCount >= 2) {
      // GOOD MATCH - Baptism indicator + some template phrases
      isValid = true;
      confidenceScore = 85.0;
    } else if (hasBaptismIndicator &&
        hasChurchIndicator &&
        baptismTermCount >= 2) {
      // ACCEPTABLE MATCH - Baptism indicator + church context + baptism terms
      isValid = true;
      confidenceScore = 75.0;
      warnings.add(
        'Document appears to be a baptism certificate but template structure not fully matched',
      );
    } else if (templatePhraseCount >= 2 && baptismTermCount >= 3) {
      // WEAK MATCH - Some template phrases + baptism terms
      isValid = true;
      confidenceScore = 60.0;
      warnings.add(
        'Document contains some baptism certificate elements but may not be a valid certificate',
      );
    } else {
      // INVALID - Not enough evidence
      isValid = false;
      confidenceScore = 0.0;
    }

    if (confidenceScore > 100) confidenceScore = 100.0;

    if (isValid) {
      return DocumentValidationResult(
        isValid: true,
        missingFields: [],
        invalidFields: [],
        warnings: warnings,
        confidenceScore: confidenceScore,
        extractedData: {
          'document_type': config.displayName,
          'validation_method': 'exact_template',
          'template_phrases_count': templatePhraseCount,
          'baptism_indicator': foundIndicator,
          'church_indicator': hasChurchIndicator,
          'baptism_terms_count': baptismTermCount,
          'found_phrases': foundPhrases,
        },
        errorMessage: null,
      );
    } else {
      return DocumentValidationResult(
        isValid: false,
        missingFields: ['baptism_certificate_template'],
        invalidFields: ['document_format'],
        warnings: [
          'Document does not match the required baptism certificate template format',
        ],
        confidenceScore: 0.0,
        extractedData: {
          'template_phrases_count': templatePhraseCount,
          'baptism_terms_count': baptismTermCount,
        },
        errorMessage:
            'Invalid document: Please upload a valid baptism certificate with the proper format.',
      );
    }
  }

  /// Validate basic file properties (type, size, etc.)
  static bool _validateFileBasics(PlatformFile documentFile) {
    print(
      'DEBUG: Validating file basics - name: ${documentFile.name}, size: ${documentFile.size}',
    );

    // Check file extension
    final fileName = documentFile.name.toLowerCase();
    final validExtensions = ['.jpg', '.jpeg', '.png', '.pdf', '.doc', '.docx'];
    final hasValidExtension = validExtensions.any(
      (ext) => fileName.endsWith(ext),
    );

    if (!hasValidExtension) {
      print('DEBUG: Invalid file extension: $fileName');
      return false;
    }

    // Check file size (max 10MB)
    const maxFileSize = 10 * 1024 * 1024; // 10MB in bytes
    if (documentFile.size > maxFileSize) {
      print('DEBUG: File too large: ${documentFile.size} bytes');
      return false;
    }

    // Check minimum file size (at least 1KB to avoid empty files)
    const minFileSize = 1024; // 1KB in bytes
    if (documentFile.size < minFileSize) {
      print('DEBUG: File too small: ${documentFile.size} bytes');
      return false;
    }

    print('DEBUG: File validation passed');
    return true;
  }

  /// Extract text from document using OCR
  static Future<_DocumentOcrResult> _extractTextFromDocument(
    PlatformFile documentFile,
  ) async {
    try {
      // Get file bytes (works for both web and mobile)
      Uint8List bytes;
      if (documentFile.bytes != null) {
        // Web platform - bytes are already available
        bytes = documentFile.bytes!;
      } else if (documentFile.path != null) {
        // Mobile platform - read from file path
        bytes = await File(documentFile.path!).readAsBytes();
      } else {
        // Fallback - cannot read file
        throw Exception('Unable to read file: no bytes or path available');
      }
      final base64Image = base64Encode(bytes);

      // Prepare OCR request with improved format
      final requestBody = jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1},
            ],
            'imageContext': {
              'languageHints': ['en', 'tl'], // English and Tagalog
            },
          },
        ],
      });

      print('DEBUG: Making Vision API request...');

      // Make API call with better error handling
      final response = await http
          .post(
            Uri.parse(
              'https://vision.googleapis.com/v1/images:annotate?key=${DefaultFirebaseOptions.visionApiKey}',
            ),
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'Parish-App/1.0',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('DEBUG: Vision API response received');

        final responses = result['responses'] as List?;

        if (responses != null && responses.isNotEmpty) {
          final firstResponse = responses[0] as Map<String, dynamic>?;
          final qualityResult = _evaluateOcrQuality(firstResponse);

          // Try DOCUMENT_TEXT_DETECTION first
          final fullTextAnnotation = firstResponse?['fullTextAnnotation'];
          if (fullTextAnnotation != null &&
              fullTextAnnotation['text'] != null) {
            final extractedText = fullTextAnnotation['text'] as String;
            print(
              'DEBUG: Document text extracted: ${extractedText.substring(0, extractedText.length > 100 ? 100 : extractedText.length)}...',
            );
            return _DocumentOcrResult(
              text: extractedText,
              qualityIssues: qualityResult.qualityIssues,
              warnings: qualityResult.warnings,
              qualityScore: qualityResult.qualityScore,
              qualityData: qualityResult.qualityData,
            );
          }

          // Fallback to textAnnotations
          final textAnnotations = firstResponse?['textAnnotations'] as List?;
          if (textAnnotations != null && textAnnotations.isNotEmpty) {
            final extractedText = textAnnotations
                .map((annotation) => annotation['text'] as String?)
                .where((text) => text != null && text.isNotEmpty)
                .join(' ');

            if (extractedText.isNotEmpty) {
              print(
                'DEBUG: Text annotations extracted: ${extractedText.substring(0, extractedText.length > 100 ? 100 : extractedText.length)}...',
              );
              return _DocumentOcrResult(
                text: extractedText,
                qualityIssues: qualityResult.qualityIssues,
                warnings: qualityResult.warnings,
                qualityScore: qualityResult.qualityScore,
                qualityData: qualityResult.qualityData,
              );
            }
          }

          // Try TEXT_DETECTION as last resort
          final textDetections = firstResponse?['textAnnotations'] as List?;
          if (textDetections != null && textDetections.isNotEmpty) {
            final extractedText = textDetections
                .map((detection) => detection['description'] as String?)
                .where((text) => text != null && text.isNotEmpty)
                .join(' ');

            if (extractedText.isNotEmpty) {
              print(
                'DEBUG: Text detections extracted: ${extractedText.substring(0, extractedText.length > 100 ? 100 : extractedText.length)}...',
              );
              return _DocumentOcrResult(
                text: extractedText,
                qualityIssues: qualityResult.qualityIssues,
                warnings: qualityResult.warnings,
                qualityScore: qualityResult.qualityScore,
                qualityData: qualityResult.qualityData,
              );
            }
          }
        }

        print('DEBUG: Vision API: No text found in response');
        print(
          'DEBUG: Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...',
        );
        return const _DocumentOcrResult(
          text: '',
          qualityIssues: [],
          warnings: [],
          qualityScore: 0.0,
          qualityData: {'ocr_text_found': false},
        );
      } else {
        print(
          'DEBUG: Vision API Error: ${response.statusCode} - ${response.body}',
        );
        return const _DocumentOcrResult(
          text: '',
          qualityIssues: [],
          warnings: [],
          qualityScore: 0.0,
          qualityData: {'ocr_request_failed': true},
        );
      }
    } catch (e) {
      print('OCR Error: $e');
      // Return empty string to trigger fallback
      return const _DocumentOcrResult(
        text: '',
        qualityIssues: [],
        warnings: [],
        qualityScore: 0.0,
        qualityData: {'ocr_exception': true},
      );
    }
  }

  static _DocumentOcrResult _evaluateOcrQuality(
    Map<String, dynamic>? visionResponse,
  ) {
    final issues = <String>[];
    final warnings = <String>[];
    final qualityData = <String, dynamic>{};
    double qualityScore = 100.0;

    final fullTextAnnotation = visionResponse?['fullTextAnnotation'];
    if (fullTextAnnotation is! Map<String, dynamic>) {
      return const _DocumentOcrResult(
        text: '',
        qualityIssues: [],
        warnings: [],
        qualityScore: 100.0,
        qualityData: {},
      );
    }

    final wordConfidences = <double>[];
    int edgeBlockCount = 0;
    int exactEdgeBlockCount = 0;
    int blockCount = 0;
    int readableWordCount = 0;
    double? smallestPageWidth;
    double? smallestPageHeight;

    final pages = fullTextAnnotation['pages'];
    if (pages is List) {
      for (final page in pages) {
        if (page is! Map<String, dynamic>) continue;

        final pageWidth = _asDouble(page['width']);
        final pageHeight = _asDouble(page['height']);
        if (pageWidth != null && pageHeight != null) {
          smallestPageWidth = smallestPageWidth == null
              ? pageWidth
              : (pageWidth < smallestPageWidth ? pageWidth : smallestPageWidth);
          smallestPageHeight = smallestPageHeight == null
              ? pageHeight
              : (pageHeight < smallestPageHeight
                    ? pageHeight
                    : smallestPageHeight);
        }
        final edgeMarginX = pageWidth == null ? null : pageWidth * 0.015;
        final edgeMarginY = pageHeight == null ? null : pageHeight * 0.015;

        final blocks = page['blocks'];
        if (blocks is! List) continue;

        for (final block in blocks) {
          if (block is! Map<String, dynamic>) continue;
          blockCount++;

          if (pageWidth != null &&
              pageHeight != null &&
              edgeMarginX != null &&
              edgeMarginY != null &&
              _boundingPolyTouchesEdge(
                block['boundingBox'],
                pageWidth,
                pageHeight,
                edgeMarginX,
                edgeMarginY,
              )) {
            edgeBlockCount++;
          }

          if (pageWidth != null &&
              pageHeight != null &&
              _boundingPolyTouchesEdge(
                block['boundingBox'],
                pageWidth,
                pageHeight,
                1,
                1,
              )) {
            exactEdgeBlockCount++;
          }

          final paragraphs = block['paragraphs'];
          if (paragraphs is! List) continue;

          for (final paragraph in paragraphs) {
            if (paragraph is! Map<String, dynamic>) continue;
            final words = paragraph['words'];
            if (words is! List) continue;

            for (final word in words) {
              if (word is! Map<String, dynamic>) continue;
              final confidence = _asDouble(word['confidence']);
              final symbols = word['symbols'];
              if (symbols is List && symbols.isNotEmpty) {
                readableWordCount++;
              }
              if (confidence != null) {
                wordConfidences.add(confidence);
              }
            }
          }
        }
      }
    }

    if (smallestPageWidth != null && smallestPageHeight != null) {
      final shortSide = smallestPageWidth < smallestPageHeight
          ? smallestPageWidth
          : smallestPageHeight;
      final longSide = smallestPageWidth > smallestPageHeight
          ? smallestPageWidth
          : smallestPageHeight;

      qualityData['pageWidth'] = smallestPageWidth;
      qualityData['pageHeight'] = smallestPageHeight;
      qualityData['shortSidePixels'] = shortSide;
      qualityData['longSidePixels'] = longSide;

      if (shortSide < 700 || longSide < 1000) {
        issues.add('image_resolution_too_low');
        warnings.add(
          'The image resolution is too low for reliable document verification.',
        );
        qualityScore = qualityScore > 20.0 ? 20.0 : qualityScore;
      }
    }

    if (wordConfidences.isNotEmpty) {
      final averageConfidence =
          wordConfidences.reduce((a, b) => a + b) / wordConfidences.length;
      final lowConfidenceWords = wordConfidences
          .where((confidence) => confidence < 0.45)
          .length;
      final lowConfidenceRatio = lowConfidenceWords / wordConfidences.length;

      qualityData['averageWordConfidence'] = averageConfidence;
      qualityData['lowConfidenceWordRatio'] = lowConfidenceRatio;
      qualityData['wordConfidenceCount'] = wordConfidences.length;

      if (wordConfidences.length >= 12 &&
          (averageConfidence < 0.55 || lowConfidenceRatio > 0.45)) {
        issues.add('image_blurry_or_unreadable');
        warnings.add(
          'OCR confidence is low, which usually means the document is blurry or hard to read.',
        );
        qualityScore = 20.0;
      }
    }

    qualityData['readableWordCount'] = readableWordCount;
    if (readableWordCount < 8) {
      issues.add('insufficient_readable_text');
      warnings.add(
        'The document does not have enough readable OCR text for reliable verification.',
      );
      qualityScore = qualityScore > 15.0 ? 15.0 : qualityScore;
    }

    qualityData['edgeBlockCount'] = edgeBlockCount;
    qualityData['exactEdgeBlockCount'] = exactEdgeBlockCount;
    qualityData['textBlockCount'] = blockCount;

    final edgeBlockRatio = blockCount == 0 ? 0.0 : edgeBlockCount / blockCount;
    qualityData['edgeBlockRatio'] = edgeBlockRatio;

    if (blockCount >= 4 &&
        ((exactEdgeBlockCount >= 2 && edgeBlockRatio >= 0.25) ||
            (edgeBlockCount >= 3 && edgeBlockRatio >= 0.45))) {
      issues.add('document_cropped');
      warnings.add(
        'Detected text too close to the image edge, which suggests part of the document may be cropped.',
      );
      qualityScore = qualityScore > 25.0 ? 25.0 : qualityScore;
    }

    return _DocumentOcrResult(
      text: '',
      qualityIssues: issues,
      warnings: warnings,
      qualityScore: qualityScore,
      qualityData: qualityData,
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _boundingPolyTouchesEdge(
    dynamic boundingPoly,
    double width,
    double height,
    double marginX,
    double marginY,
  ) {
    if (boundingPoly is! Map<String, dynamic>) return false;
    final vertices = boundingPoly['vertices'];
    if (vertices is! List || vertices.isEmpty) return false;

    final xs = <double>[];
    final ys = <double>[];

    for (final vertex in vertices) {
      if (vertex is! Map<String, dynamic>) continue;
      final x = _asDouble(vertex['x']);
      final y = _asDouble(vertex['y']);
      if (x != null) xs.add(x);
      if (y != null) ys.add(y);
    }

    if (xs.isEmpty || ys.isEmpty) return false;

    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);

    return minX <= marginX ||
        minY <= marginY ||
        maxX >= width - marginX ||
        maxY >= height - marginY;
  }

  /// Apply validation rules based on sacrament type
  static _ValidationResult _applyValidationRules(
    String extractedText,
    String sacramentType,
    String requirementType,
  ) {
    final missingFields = <String>[];
    final invalidFields = <String>[];
    final warnings = <String>[];
    double confidenceScore = 0.0;

    // Get required fields for this sacrament type
    List<String> requiredFields = [];
    switch (sacramentType.toLowerCase()) {
      case 'baptism':
        requiredFields =
            SacramentValidationRules.baptismRequirements[requirementType] ?? [];
        break;
      case 'confirmation':
        requiredFields =
            SacramentValidationRules
                .confirmationRequirements[requirementType] ??
            [];
        break;
      case 'wedding':
        requiredFields =
            SacramentValidationRules.weddingRequirements[requirementType] ?? [];
        break;
      case 'funeral':
        requiredFields =
            SacramentValidationRules.funeralRequirements[requirementType] ?? [];
        break;
      default:
        // Unknown sacrament type - be very strict and require basic document elements
        requiredFields = ['full_name', 'date'];
        warnings.add('Unknown sacrament type: $sacramentType');
        break;
    }

    // If no specific requirements found, use basic validation
    if (requiredFields.isEmpty) {
      requiredFields = ['full_name', 'date'];
      // Do not add a user-facing warning when falling back to basic validation.
      // The UI should only show warnings for actual validation issues.
    }

    // Check for required fields
    for (final field in requiredFields) {
      if (!_containsField(extractedText, field)) {
        missingFields.add(field);
      }
    }

    // Check document validity indicators
    final hasValidSignature = _containsValidSignature(extractedText);
    final hasValidDate = _containsValidDate(extractedText);
    final hasOfficialSeal = _containsOfficialSeal(extractedText);

    if (!hasValidSignature && _requiresSignature(requirementType)) {
      invalidFields.add('signature');
    }

    if (!hasValidDate && _requiresDate(requirementType)) {
      invalidFields.add('date');
    }

    if (!hasOfficialSeal && _requiresOfficialSeal(requirementType)) {
      warnings.add('Official seal not detected');
    }

    // Calculate confidence score
    final foundFields = requiredFields.length - missingFields.length;

    if (requiredFields.isNotEmpty) {
      confidenceScore = (foundFields / requiredFields.length) * 100;
    } else {
      // If no specific requirements, give reasonable confidence based on basic checks
      confidenceScore = 75.0; // Good confidence for documents with keywords
      if (hasValidSignature) confidenceScore += 10;
      if (hasValidDate) confidenceScore += 10;
      if (hasOfficialSeal) confidenceScore += 5;
      if (confidenceScore > 100) confidenceScore = 100;
    }

    final isValid = missingFields.isEmpty && invalidFields.isEmpty;

    print('DEBUG: Final validation result:');
    print('DEBUG: - isValid: $isValid');
    print('DEBUG: - confidenceScore: $confidenceScore');
    print('DEBUG: - missingFields: $missingFields');
    print('DEBUG: - invalidFields: $invalidFields');
    print('DEBUG: - warnings: $warnings');

    return _ValidationResult(
      isValid: isValid,
      missingFields: missingFields,
      invalidFields: invalidFields,
      warnings: warnings,
      confidenceScore: confidenceScore,
    );
  }

  /// Extract structured data from document text
  static Future<Map<String, dynamic>> _extractStructuredData(
    String extractedText,
    String sacramentType,
    String requirementType,
  ) async {
    final data = <String, dynamic>{};

    // Extract common fields
    data['full_name'] = _extractFullName(extractedText);
    data['date_of_birth'] = _extractDate(extractedText);
    data['place_of_birth'] = _extractPlace(extractedText);
    data['parent_names'] = _extractParentNames(extractedText);

    // Extract sacrament-specific fields
    switch (sacramentType.toLowerCase()) {
      case 'wedding':
        data['spouse_name'] = _extractSpouseName(extractedText);
        data['witness_names'] = _extractWitnessNames(extractedText);
        break;
      case 'funeral':
        data['date_of_death'] = _extractDeathDate(extractedText);
        data['cause_of_death'] = _extractCauseOfDeath(extractedText);
        break;
    }

    return data;
  }

  /// Helper methods for field extraction
  static bool _containsField(String text, String field) {
    final fieldVariations = _getFieldVariations(field);
    return fieldVariations.any(
      (variation) => text.toLowerCase().contains(variation.toLowerCase()),
    );
  }

  static List<String> _getFieldVariations(String field) {
    switch (field.toLowerCase()) {
      case 'full_name':
        return ['name', 'full name', 'pangalan', 'ngalan'];
      case 'date_of_birth':
        return [
          'date of birth',
          'birth date',
          'petsa ng kapanganakan',
          'kapanganakan',
        ];
      case 'parent_names':
        return ['parent', 'mother', 'father', 'ama', 'ina', 'magulang'];
      default:
        return [field.toLowerCase()];
    }
  }

  static bool _containsValidSignature(String text) {
    final signatureIndicators = [
      'signature',
      'signed',
      'pirma',
      'lagda',
      'signature ng',
      'pinirmahan',
    ];
    return signatureIndicators.any(
      (indicator) => text.toLowerCase().contains(indicator),
    );
  }

  static bool _containsValidDate(String text) {
    final datePatterns = [
      RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{4}\b'), // MM/DD/YYYY
      RegExp(r'\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b'), // YYYY/MM/DD
      RegExp(r'\b\w{3,9}\s+\d{1,2},?\s+\d{4}\b'), // Month DD, YYYY
    ];
    return datePatterns.any((pattern) => pattern.hasMatch(text));
  }

  static bool _containsOfficialSeal(String text) {
    final sealIndicators = [
      'official seal',
      'seal',
      'dry seal',
      'tsinel',
      'seal of',
      'opisyal na tsinel',
    ];
    return sealIndicators.any(
      (indicator) => text.toLowerCase().contains(indicator),
    );
  }

  static bool _requiresSignature(String requirementType) {
    final signatureRequired = [
      'Birth Certificate',
      'Marriage Certificate',
      'Death Certificate',
      'CENOMAR',
    ];
    return signatureRequired.contains(requirementType);
  }

  static bool _requiresDate(String requirementType) {
    final dateRequired = [
      'Birth Certificate',
      'Marriage Certificate',
      'Death Certificate',
      'Confirmation Certificate',
    ];
    return dateRequired.contains(requirementType);
  }

  static bool _requiresOfficialSeal(String requirementType) {
    final sealRequired = [
      'Birth Certificate',
      'Marriage Certificate',
      'Death Certificate',
      'CENOMAR',
    ];
    return sealRequired.contains(requirementType);
  }

  /// Text extraction helpers
  static String _extractFullName(String text) {
    final namePattern = RegExp(
      r'(?:Name|Pangalan):\s*([A-Z][a-z]+\s+[A-Z][a-z]+)',
      caseSensitive: false,
    );
    final match = namePattern.firstMatch(text);
    return match?.group(1) ?? '';
  }

  static String _extractDate(String text) {
    final datePattern = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{4}\b');
    final match = datePattern.firstMatch(text);
    return match?.group(0) ?? '';
  }

  static String _extractPlace(String text) {
    final placePattern = RegExp(
      r'(?:Place|Lugar|Born in|Ipinanganak sa):\s*([A-Za-z\s,]+)',
      caseSensitive: false,
    );
    final match = placePattern.firstMatch(text);
    return match?.group(1) ?? '';
  }

  static String _extractParentNames(String text) {
    final parents = <String>[];
    final fatherPattern = RegExp(
      r'(?:Father|Ama):\s*([A-Z][a-z]+\s+[A-Z][a-z]+)',
      caseSensitive: false,
    );
    final motherPattern = RegExp(
      r'(?:Mother|Ina):\s*([A-Z][a-z]+\s+[A-Z][a-z]+)',
      caseSensitive: false,
    );

    final fatherMatch = fatherPattern.firstMatch(text);
    final motherMatch = motherPattern.firstMatch(text);

    if (fatherMatch != null) parents.add(fatherMatch.group(1)!);
    if (motherMatch != null) parents.add(motherMatch.group(1)!);

    return parents.join(', ');
  }

  static String _extractSpouseName(String text) {
    final spousePattern = RegExp(
      r'(?:Spouse|Asawa):\s*([A-Z][a-z]+\s+[A-Z][a-z]+)',
      caseSensitive: false,
    );
    final match = spousePattern.firstMatch(text);
    return match?.group(1) ?? '';
  }

  static String _extractWitnessNames(String text) {
    final witnesses = <String>[];
    final witnessPattern = RegExp(
      r'(?:Witness|Saksi):\s*([A-Z][a-z]+\s+[A-Z][a-z]+)',
      caseSensitive: false,
    );

    final matches = witnessPattern.allMatches(text);
    for (final match in matches) {
      witnesses.add(match.group(1)!);
    }

    return witnesses.join(', ');
  }

  static String _extractDeathDate(String text) {
    final deathDatePattern = RegExp(
      r'(?:Died|Namatay|Death Date):\s*(\d{1,2}[/-]\d{1,2}[/-]\d{4})',
      caseSensitive: false,
    );
    final match = deathDatePattern.firstMatch(text);
    return match?.group(1) ?? '';
  }

  static String _extractCauseOfDeath(String text) {
    final causePattern = RegExp(
      r'(?:Cause|Dahilan|Cause of Death):\s*([A-Za-z\s,]+)',
      caseSensitive: false,
    );
    final match = causePattern.firstMatch(text);
    return match?.group(1) ?? '';
  }
}

/// Internal validation result class
class _ValidationResult {
  final bool isValid;
  final List<String> missingFields;
  final List<String> invalidFields;
  final List<String> warnings;
  final double confidenceScore;

  _ValidationResult({
    required this.isValid,
    required this.missingFields,
    required this.invalidFields,
    required this.warnings,
    required this.confidenceScore,
  });
}
