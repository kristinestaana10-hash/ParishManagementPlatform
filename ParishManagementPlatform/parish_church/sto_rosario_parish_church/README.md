# sto_rosario_parish_church

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## AI & Document Processing APIs

### AI
**Groq API** (REST API - no SDK)
- **Endpoint:** `https://api.groq.com/openai/v1/chat/completions`
- **Models:** `llama-3.1-8b-instant`, `llama3-8b-8192`
- **Usage:** High-speed inference engine for real-time AI chatbot responses
- **Modules:** AI Chatbot Module (Automated parishioner support)

### AI Document Processing
**Google Cloud Vision API** (via REST endpoint)
- **Endpoint:** `https://vision.googleapis.com/v1/images:annotate`
- **Package:** `googleapis_auth: ^1.0.0` (authentication only)
- **Usage:** AI-powered document analysis for extracting and validating sacrament requirements and uploaded files
- **Modules:** Document Verification Module (Requirement Checking)
