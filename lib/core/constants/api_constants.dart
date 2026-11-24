import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Primary Gemini Multimodal Model (Active, fast ~2s)
  static const String geminiModel = 'gemini-3.5-flash-lite';

  // Ordered fallback Gemini models that are active
  static const List<String> fallbackModels = [
    'gemini-3.5-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-3.5-flash',
  ];

  // Groq Fast LLM Models (Ultra-fast inference under 1 second)
  static const String groqModel = 'openai/gpt-oss-20b';
  static const String groqApiEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  // Groq API Key - loaded from .env
  static String get groqApiKey {
    return (dotenv.env['GROQ_API_KEY'] ??
            const String.fromEnvironment('GROQ_API_KEY', defaultValue: ''))
        .trim();
  }

  // Free OCR.Space API endpoint & key
  static const String ocrSpaceEndpoint = 'https://api.ocr.space/parse/image';
  static String get ocrSpaceApiKey {
    final key = (dotenv.env['OCR_SPACE_API_KEY'] ?? '').trim();
    return key.isNotEmpty ? key : 'helloworld';
  }

  // Model response timeout (in seconds) - fast failover
  static const int modelTimeoutSeconds = 12;

  // API Key - loaded from .env or dart-define
  static String get geminiApiKey {
    return (dotenv.env['GEMINI_API_KEY'] ??
            const String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''))
        .trim();
  }
}

