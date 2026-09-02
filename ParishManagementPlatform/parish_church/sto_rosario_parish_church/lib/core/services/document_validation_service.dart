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

  // Low resolution and edge-text signals are useful warnings, but they are not
  // reliable enough to reject an otherwise readable, correctly identified
  // civil document.  Missing readable text remains a hard stop.
  bool get hasBlockingQualityIssues =>
      qualityIssues.contains('insufficient_readable_text');
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

      // OCR geometry/confidence can be incomplete for a valid scan.  Only use
      // this gate when no readable OCR text was recovered; otherwise document
      // identity is decided by the evidence check below.
      if (ocrResult.hasBlockingQualityIssues && extractedText.trim().isEmpty) {
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

        final apiReason = ocrResult.qualityData['ocr_api_reason']?.toString();
        if (apiReason != null && apiReason.isNotEmpty) {
          final apiMessage = ocrResult.qualityData['ocr_api_error']?.toString();
          final serviceMessage = apiReason == 'BILLING_DISABLED'
              ? 'Document verification is temporarily unavailable because Google Cloud Vision billing is disabled for this project. This file was not rejected as invalid; an administrator must enable billing for the Vision API project and try again.'
              : apiReason == 'SERVICE_DISABLED'
              ? 'Document verification is temporarily unavailable because the Google Cloud Vision API is disabled for this project. This file was not rejected as invalid; an administrator must enable the API and try again.'
              : apiReason == 'API_KEY_INVALID' || apiReason == 'API_KEY_SERVICE_BLOCKED'
              ? 'Document verification is temporarily unavailable because its API key is invalid or blocked. This file was not rejected as invalid; an administrator must update the Vision API configuration and try again.'
              : 'Document verification is temporarily unavailable. This file was not rejected as invalid. ${apiMessage ?? 'Please try again later.'}';
          return DocumentValidationResult(
            isValid: false,
            missingFields: const ['document_verification_service'],
            invalidFields: const [],
            warnings: const [],
            confidenceScore: 0.0,
            extractedData: ocrResult.qualityData,
            errorMessage: serviceMessage,
          );
        }

        if (ocrResult.qualityData['ocr_unsupported_format'] == true) {
          return DocumentValidationResult(
            isValid: false,
            missingFields: ['ocr_supported_format'],
            invalidFields: ['unsupported_ocr_format'],
            warnings: ocrResult.warnings,
            confidenceScore: 0.0,
            extractedData: ocrResult.qualityData,
            errorMessage:
                'This Word document cannot be verified directly. Please upload the original as a PDF or a clear JPG/PNG scan.',
          );
        }

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
    if (config.displayName == 'Birth Certificate') {
      return _validateBirthCertificate(extractedText, config);
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

  /// Birth certificates are issued in several PSA and Local Civil Registrar
  /// layouts.  A title alone is not sufficient evidence (a random document can
  /// mention PSA), but requiring one exact layout rejects legitimate copies.
  /// Validate the combination of issuer, birth-specific labels, and identity
  /// data instead.
  static DocumentValidationResult _validateBirthCertificate(
    String extractedText,
    DocumentTypeConfig config,
  ) {
    final text = extractedText.toLowerCase();
    final hasTitle = [
      'certificate of live birth',
      'birth certificate',
      'certificate of birth',
      'sertipiko ng kapanganakan',
      'live birth',
    ].any(text.contains) ||
        (text.contains('certificate') &&
            text.contains('birth') &&
            (text.contains('live') || text.contains('kapanganakan')));
    final hasIssuer = [
      'philippine statistics authority',
      'local civil registrar',
      'civil registrar',
      'civil registry',
      'republic of the philippines',
      'psa',
    ].any(text.contains);
    final fieldLabels = [
      'name of child',
      'name of the child',
      'child name',
      'name of registrant',
      'surname',
      'first name',
      'middle name',
      'date of birth',
      'place of birth',
      'sex',
      'father',
      'mother',
      'maiden name',
      'citizenship',
      'legitimacy',
      'date of occurrence',
      'place of occurrence',
      'type of birth',
      'informant',
      'attendant',
      'pangalan',
      'kapanganakan',
      'ama',
      'ina',
    ];
    final fieldCount = fieldLabels.where(text.contains).length;
    final hasBirthDate = _extractBirthDate(extractedText).isNotEmpty;
    final hasParent = text.contains('father') ||
        text.contains('mother') ||
        text.contains('ama') ||
        text.contains('ina');
    // A real certificate can have a partially obscured title, but a random
    // file is very unlikely to contain both an issuing authority and several
    // civil-registry fields.  This deliberately avoids a single-keyword rule.
    final isValid = (hasTitle && hasIssuer && fieldCount >= 1) ||
        (hasTitle && fieldCount >= 3) ||
        (hasIssuer && fieldCount >= 4 && hasBirthDate && hasParent);

    if (!isValid) {
      return DocumentValidationResult(
        isValid: false,
        missingFields: ['birth_certificate_evidence'],
        invalidFields: ['document_format'],
        warnings: const [
          'A birth certificate must show official birth-certificate information, not only a related keyword.',
        ],
        confidenceScore: 20.0,
        extractedData: {
          'document_type': config.displayName,
          'birth_title_found': hasTitle,
          'birth_issuer_found': hasIssuer,
          'birth_field_label_count': fieldCount,
        },
        errorMessage: config.errorMessage,
      );
    }

    final confidence = 70.0 +
        (hasTitle ? 10.0 : 0.0) +
        (hasIssuer ? 10.0 : 0.0) +
        (hasBirthDate && hasParent ? 10.0 : 0.0);
    return DocumentValidationResult(
      isValid: true,
      missingFields: const [],
      invalidFields: const [],
      warnings: hasBirthDate && hasParent
          ? const []
          : const [
              'The document was recognized, but some details could not be extracted automatically.',
            ],
      confidenceScore: confidence > 100 ? 100 : confidence,
      extractedData: {
        'document_type': config.displayName,
        'validation_method': 'birth_certificate_evidence',
        'birth_title_found': hasTitle,
        'birth_issuer_found': hasIssuer,
        'birth_field_label_count': fieldCount,
      },
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
      final fileName = documentFile.name.toLowerCase();
      final isPdf = fileName.endsWith('.pdf');
      final isUnsupportedOfficeFile =
          fileName.endsWith('.doc') || fileName.endsWith('.docx');
      if (isUnsupportedOfficeFile) {
        // Vision's image endpoint cannot read Office files. Do not send their
        // binary data as an image and then mislabel a valid document as random.
        return const _DocumentOcrResult(
          text: '',
          qualityIssues: [],
          warnings: [
            'Word documents cannot be OCR-verified directly. Upload a PDF or a clear JPG/PNG scan instead.',
          ],
          qualityScore: 0.0,
          qualityData: {'ocr_unsupported_format': true},
        );
      }
      final base64Image = base64Encode(bytes);

      // PDFs require Vision's file endpoint. Sending a PDF to images:annotate
      // always fails even when the certificate itself is legitimate.
      final requestBody = jsonEncode({
        'requests': [
          isPdf
              ? {
                  'inputConfig': {
                    'mimeType': 'application/pdf',
                    'content': base64Image,
                  },
                  'features': [
                    {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1},
                  ],
                  'imageContext': {
                    'languageHints': ['en', 'fil', 'tl'],
                  },
                }
              : {
                  'image': {'content': base64Image},
                  'features': [
                    {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1},
                  ],
                  'imageContext': {
                    'languageHints': ['en', 'fil', 'tl'],
                  },
                },
        ],
      });

      print('DEBUG: Making Vision API request...');

      // Make API call with better error handling
      final response = await http
          .post(
            Uri.parse(
              'https://vision.googleapis.com/v1/${isPdf ? 'files:annotate' : 'images:annotate'}?key=${DefaultFirebaseOptions.visionApiKey}',
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

        List? responses;
        if (isPdf) {
          final fileResponses = result['responses'];
          if (fileResponses is List && fileResponses.isNotEmpty) {
            final fileResponse = fileResponses.first;
            if (fileResponse is Map<String, dynamic>) {
              final pageResponses = fileResponse['responses'];
              if (pageResponses is List) responses = pageResponses;
            }
          }
        } else if (result['responses'] is List) {
          responses = result['responses'] as List;
        }

        if (responses != null && responses.isNotEmpty) {
          final pageResponses = responses
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
          if (pageResponses.isEmpty) {
            return const _DocumentOcrResult(
              text: '',
              qualityIssues: [],
              warnings: [],
              qualityScore: 0.0,
              qualityData: {'ocr_text_found': false},
            );
          }
          final firstResponse = pageResponses.first;
          final qualityResult = _evaluateOcrQuality(firstResponse);

          // PDFs can have more than one OCR response. Combine all readable
          // pages so a required field on a later page is not silently missed.
          final fullText = pageResponses
              .map((page) => page['fullTextAnnotation'])
              .whereType<Map<String, dynamic>>()
              .map((annotation) => annotation['text']?.toString() ?? '')
              .where((text) => text.trim().isNotEmpty)
              .join('\n');
          if (fullText.isNotEmpty) {
            final extractedText = fullText;
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
          final textAnnotations = firstResponse['textAnnotations'] as List?;
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
          final textDetections = firstResponse['textAnnotations'] as List?;
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
        final errorData = _visionErrorData(response.body);
        print(
          'DEBUG: Vision API Error: ${response.statusCode} - ${response.body}',
        );
        return _DocumentOcrResult(
          text: '',
          qualityIssues: const [],
          warnings: const [],
          qualityScore: 0.0,
          qualityData: {
            'ocr_request_failed': true,
            'ocr_http_status': response.statusCode,
            ...errorData,
          },
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

  static Map<String, dynamic> _visionErrorData(String responseBody) {
    try {
      final parsed = jsonDecode(responseBody);
      if (parsed is! Map<String, dynamic>) return const {};
      final error = parsed['error'];
      if (error is! Map<String, dynamic>) return const {};
      String? reason;
      final details = error['details'];
      if (details is List) {
        for (final detail in details) {
          if (detail is Map<String, dynamic> && detail['reason'] != null) {
            reason = detail['reason'].toString();
            break;
          }
        }
      }
      return {
        'ocr_api_reason': reason ?? 'VISION_API_REQUEST_FAILED',
        'ocr_api_error': error['message']?.toString() ??
            'The OCR service did not accept this request.',
      };
    } catch (_) {
      return const {
        'ocr_api_reason': 'VISION_API_REQUEST_FAILED',
        'ocr_api_error': 'The OCR service returned an unreadable error response.',
      };
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

    // A requirement is the extraction target.  This prevents a document from
    // being treated as a generic block of text and lets the form safely use
    // birth-certificate fields only when a birth certificate was uploaded.
    final isBirthCertificate = requirementType.toLowerCase().contains('birth') ||
        requirementType.toLowerCase().contains('kapanganakan');
    data['extraction_target'] =
        isBirthCertificate ? 'birth_certificate' : 'general_document';

    // Extract common fields
    final fatherName = _extractLabeledValue(extractedText, [
      "father(?:'s)?(?: (?:full )?name)?",
      'name of father',
      'father name',
      'pangalan ng ama',
      'ama',
    ]);
    final motherName = _extractLabeledValue(extractedText, [
      "mother(?:'s)?(?: maiden)?(?: name)?",
      'name of mother',
      'mother name',
      'pangalan ng ina',
      'ina',
    ]);
    if (isBirthCertificate) {
      data['full_name'] = _extractChildName(extractedText);
      data['date_of_birth'] = _extractBirthDate(extractedText);
      data['place_of_birth'] = _extractLabeledValue(extractedText, [
        'place of (?:birth|occurrence)',
        'born in',
        'place/lugar of birth',
        'lugar ng kapanganakan',
        'pook ng kapanganakan',
      ]);
      data['father_name'] = fatherName;
      data['mother_name'] = motherName;
      data['parent_names'] = [fatherName, motherName]
          .where((name) => name.isNotEmpty)
          .join(', ');
    }

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
  static String _extractChildName(String text) {
    return _extractLabeledValue(text, [
      'name of (?:the )?child',
      "child(?:'s)? name",
      'name of registrant',
      'name of infant',
      'name of baby',
      'name of person',
      'complete name',
      'full name',
      'pangalan ng bata',
      'buong pangalan',
      'pangalan',
      'name',
    ]);
  }

  static String _extractBirthDate(String text) {
    final labeled = _extractLabeledValue(text, [
      'date of (?:birth|occurrence)',
      'birth date',
      'date born',
      'birthday',
      'petsa ng kapanganakan',
    ], valueCanBeDate: true);
    if (labeled.isNotEmpty) return _normaliseDate(labeled);
    return _normaliseDate(_extractDate(text));
  }

  static String _extractLabeledValue(
    String text,
    List<String> labels, {
    bool valueCanBeDate = false,
  }) {
    // Vision normally keeps lines, but a scan can place table headings and
    // values on one line or separate them with irregular whitespace. Search
    // by nearby labels instead of assuming a fixed certificate position.
    final candidates = <String>[];
    for (final label in labels) {
      // OCR can split a printed label across lines or insert extra spaces in
      // a table cell; allow whitespace anywhere a label contains a space.
      final flexibleLabel = label.replaceAll(' ', r'\s+');
      final pattern = RegExp(
        '(?:^|\\n|\\b)(?:$flexibleLabel)\\b\\s*[:\\-–—.]?\\s*([^\\n]{2,120})',
        caseSensitive: false,
      );
      for (final reading in _ocrReadingVariants(text)) {
        for (final match in pattern.allMatches(reading)) {
          var value = _cleanOcrFieldValue(match.group(1)!);
          value = value.replaceFirst(
            RegExp(
                r'\s+(?:sex|gender|father|mother|place|date|citizenship|nationality|informant|attendant|legitimacy|type of birth)\b.*$',
                caseSensitive: false),
            '',
          );
          if (valueCanBeDate) {
            final date = _firstDateIn(value);
            if (date.isNotEmpty) candidates.add(date);
          } else if (_isPlausibleOcrFieldValue(value)) {
            candidates.add(value);
          }
        }
      }
    }
    if (candidates.isEmpty) return '';
    candidates.sort((a, b) => _ocrCandidateScore(b).compareTo(_ocrCandidateScore(a)));
    return candidates.first;
  }

  /// Returns a few text readings for the same document. This makes extraction
  /// tolerant of OCR that separates a table label and its value onto adjacent
  /// lines, without depending on a particular PSA/LCR certificate layout.
  static Iterable<String> _ocrReadingVariants(String text) sync* {
    final normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\t\f\v ]+'), ' ');
    yield normalized;

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    for (var index = 0; index + 1 < lines.length; index++) {
      // A two-line window catches `DATE OF BIRTH` followed by its value.
      yield '${lines[index]}\n${lines[index + 1]}';
    }
  }

  static String _firstDateIn(String value) {
    final corrected = value
        .replaceAllMapped(
          RegExp(r'(\d)[Oo](\d)'),
          (match) => '${match.group(1)}0${match.group(2)}',
        )
        .replaceAllMapped(
          RegExp(r'(\d)[Il](\d)'),
          (match) => '${match.group(1)}1${match.group(2)}',
        );
    final date = RegExp(
      r'\b(?:\d{1,2}[./-]\d{1,2}[./-]\d{2,4}|\d{4}[./-]\d{1,2}[./-]\d{1,2}|(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}|\d{1,2}(?:st|nd|rd|th)?\s+(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|jul(?:y)?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?),?\s+\d{4})\b',
      caseSensitive: false,
    ).firstMatch(corrected);
    return date?.group(0) ?? '';
  }

  static bool _isPlausibleOcrFieldValue(String value) {
    if (value.length < 2 || value.length > 100) return false;
    final lowered = value.toLowerCase();
    if (RegExp(
      r'^(?:sex|gender|father|mother|place|date|citizenship|surname|first|middle|last|given|registry)\b',
    ).hasMatch(lowered)) {
      return false;
    }
    return RegExp(r'[A-Za-z]').hasMatch(value);
  }

  static int _ocrCandidateScore(String value) {
    final words = value.split(RegExp(r'\s+')).length;
    final letters = RegExp(r'[A-Za-z]').allMatches(value).length;
    final digits = RegExp(r'\d').allMatches(value).length;
    // Names and places normally have several words/letters; long runs of
    // digits are usually registry numbers that must not fill a text field.
    return (words * 10) + letters - (digits * 4) - (value.length > 80 ? 40 : 0);
  }

  static String _cleanOcrFieldValue(String value) {
    return value
        .replaceFirst(RegExp(r'^[.:-–—\s]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+[|]\s*'), ' ')
        .trim();
  }

  static String _normaliseDate(String value) {
    final trimmed = value.trim();
    final numeric = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})$')
        .firstMatch(trimmed);
    if (numeric != null) {
      final year = numeric.group(3)!.length == 2
          ? '19${numeric.group(3)}'
          : numeric.group(3)!;
      return '$year-${numeric.group(1)!.padLeft(2, '0')}-${numeric.group(2)!.padLeft(2, '0')}';
    }

    final months = <String, int>{
      'jan': 1, 'january': 1, 'feb': 2, 'february': 2,
      'mar': 3, 'march': 3, 'apr': 4, 'april': 4,
      'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
      'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9,
      'oct': 10, 'october': 10, 'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };
    final monthFirst = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?[,]?\s+(\d{4})$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    final dayFirst = RegExp(
      r'^(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]+)[,]?\s+(\d{4})$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    final month = monthFirst == null
        ? (dayFirst == null ? null : months[dayFirst.group(2)!.toLowerCase()])
        : months[monthFirst.group(1)!.toLowerCase()];
    if (month != null) {
      final day = monthFirst?.group(2) ?? dayFirst!.group(1)!;
      final year = monthFirst?.group(3) ?? dayFirst!.group(3)!;
      return '$year-${month.toString().padLeft(2, '0')}-${day.padLeft(2, '0')}';
    }
    return trimmed;
  }

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
