import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/expense_model.dart';

class GeminiOcrService {
  /// Remembers the last model that responded successfully to eliminate fallback delays
  static String? _preferredModel;

  static const String _prompt = '''
Analyze this receipt/bill image and extract expense details.
Return ONLY a valid JSON object matching this schema:
{
  "merchant": "Store or merchant name",
  "totalAmount": 0.00,
  "currency": "LKR",
  "category": "Food & Dining",
  "date": "YYYY-MM-DD",
  "items": [
    {
      "name": "Item name",
      "price": 0.00,
      "quantity": 1
    }
  ]
}
Category must be one of: Food & Dining, Groceries, Transportation, Utilities & Bills, Shopping, Entertainment, Healthcare, Education, Other.
''';

  /// Primary parsing entrypoint:
  /// 1. Tries active multimodal Gemini models (gemini-3.5-flash-lite, ~2-4s)
  /// 2. If Gemini experiences 503 high-demand, switches to Free OCR.space + Groq AI (< 1s)
  /// 3. If AI endpoints fail, uses regex extraction on OCR text
  /// 4. Returns null if scanning fails so user is never given fake data
  Future<ExpenseModel?> parseReceipt({
    required Uint8List imageBytes,
    required String userId,
    String mimeType = 'image/jpeg',
    void Function(String status)? onStatusUpdate,
  }) async {
    // 1. Try Gemini Multimodal Models
    final geminiKey = ApiConstants.geminiApiKey;
    if (geminiKey.isNotEmpty) {
      final content = [
        Content.multi([
          TextPart(_prompt),
          DataPart(mimeType, imageBytes),
        ]),
      ];

      final modelsToTry = [
        if (_preferredModel != null) _preferredModel!,
        ...ApiConstants.fallbackModels.where((m) => m != _preferredModel),
      ];

      for (final modelName in modelsToTry) {
        try {
          debugPrint('Scanning receipt with Gemini: $modelName');
          onStatusUpdate?.call('Analyzing with $modelName (~2s)...');

          final model = GenerativeModel(
            model: modelName,
            apiKey: geminiKey,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0.1,
              maxOutputTokens: 1024,
            ),
          );

          final response = await model.generateContent(content).timeout(
            Duration(seconds: ApiConstants.modelTimeoutSeconds),
            onTimeout: () {
              throw Exception('Timeout on $modelName');
            },
          );

          final responseText = response.text;
          if (responseText != null && responseText.isNotEmpty) {
            final parsed = _parseExpenseFromJson(responseText, userId);
            if (parsed.merchant.isNotEmpty && parsed.totalAmount > 0) {
              _preferredModel = modelName;
              debugPrint('Gemini OCR succeeded with $modelName!');
              return parsed;
            }
          }
        } catch (e) {
          debugPrint('Model $modelName busy or failed: $e. Trying next...');
        }
      }
    }

    // 2. Fallback: Free OCR.space + Groq AI (< 1s response)
    onStatusUpdate?.call('Extracting text via Free OCR...');
    debugPrint('Switching to OCR.space + Groq AI pipeline...');
    final ocrText = await _extractTextFromOcrSpace(imageBytes, mimeType);

    if (ocrText != null && ocrText.isNotEmpty) {
      debugPrint('OCR.space extracted ${ocrText.length} characters of receipt text.');

      // Try Groq AI with OCR text if Groq key is present
      if (ApiConstants.groqApiKey.isNotEmpty) {
        try {
          onStatusUpdate?.call('Structuring data with Groq AI (< 1s)...');
          debugPrint('Parsing OCR text with Groq AI...');
          final groqResult = await _parseWithGroqText(
            ocrText: ocrText,
            userId: userId,
          );
          if (groqResult != null) {
            debugPrint('Groq AI OCR parsing succeeded!');
            return groqResult;
          }
        } catch (e) {
          debugPrint('Groq AI parsing error: $e');
        }
      }

      // Regex fallback if Groq failed or key is missing
      debugPrint('Applying regex fallback on OCR text...');
      final regexResult = _parseTextWithRegex(ocrText, userId);
      if (regexResult != null) {
        return regexResult;
      }
    }

    // Genuinely unable to extract data - return null so UI asks user to retry or enter manually
    debugPrint('All OCR and AI pipelines exhausted. Returning null.');
    return null;
  }

  /// Extracts raw text from image using OCR.space free API
  Future<String?> _extractTextFromOcrSpace(
    Uint8List imageBytes,
    String mimeType,
  ) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await http.post(
        Uri.parse(ApiConstants.ocrSpaceEndpoint),
        body: {
          'base64Image': 'data:$mimeType;base64,$base64Image',
          'apikey': ApiConstants.ocrSpaceApiKey,
          'language': 'eng',
          'isOverlayRequired': 'false',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['ParsedResults'] != null &&
            (data['ParsedResults'] as List).isNotEmpty) {
          final text = data['ParsedResults'][0]['ParsedText'];
          if (text != null && text.toString().trim().isNotEmpty) {
            return text.toString().trim();
          }
        }
      }
    } catch (e) {
      debugPrint('OCR.space extraction error: $e');
    }
    return null;
  }

  /// High-speed JSON parsing with Groq's active LLM model
  Future<ExpenseModel?> _parseWithGroqText({
    required String ocrText,
    required String userId,
  }) async {
    final apiKey = ApiConstants.groqApiKey;
    if (apiKey.isEmpty) return null;

    final prompt = '''
Analyze this receipt text and extract expense details.
Return ONLY a valid JSON object matching this schema:
{
  "merchant": "Store or merchant name",
  "totalAmount": 0.00,
  "currency": "LKR",
  "category": "Food & Dining",
  "date": "YYYY-MM-DD",
  "items": [
    {
      "name": "Item name",
      "price": 0.00,
      "quantity": 1
    }
  ]
}
Category must be one of: Food & Dining, Groceries, Transportation, Utilities & Bills, Shopping, Entertainment, Healthcare, Education, Other.

Receipt Text:
$ocrText
''';

    final requestBody = jsonEncode({
      'model': ApiConstants.groqModel,
      'messages': [
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.1,
      'max_tokens': 1024,
    });

    final response = await http
        .post(
          Uri.parse(ApiConstants.groqApiEndpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: requestBody,
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      throw Exception('Groq API error (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices']?[0]?['message']?['content'];
    if (content == null || content.toString().isEmpty) {
      return null;
    }

    return _parseExpenseFromJson(content.toString(), userId);
  }

  /// Regex fallback extractor for receipt text
  ExpenseModel? _parseTextWithRegex(String text, String userId) {
    try {
      final lines = text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      if (lines.isEmpty) return null;

      // Extract merchant from first prominent line
      String merchant = 'Scanned Store';
      for (final line in lines) {
        if (line.length > 2 && !RegExp(r'^[0-9\W]+$').hasMatch(line)) {
          merchant = line;
          break;
        }
      }

      // Extract total
      double totalAmount = 0.0;
      final totalRegex = RegExp(
        r'(?:total|subtotal|net|amount|due|balance|lkr|rs)[\s:\.]*([0-9,]+(?:\.[0-9]{2})?)',
        caseSensitive: false,
      );
      for (final line in lines.reversed) {
        final match = totalRegex.firstMatch(line);
        if (match != null) {
          final raw = match.group(1)?.replaceAll(',', '');
          if (raw != null) {
            final parsed = double.tryParse(raw);
            if (parsed != null && parsed > 0) {
              totalAmount = parsed;
              break;
            }
          }
        }
      }

      // Extract date
      DateTime expenseDate = DateTime.now();
      final dateRegex = RegExp(
        r'\b(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{4})\b',
      );
      for (final line in lines) {
        final match = dateRegex.firstMatch(line);
        if (match != null) {
          final rawDate = match.group(1);
          if (rawDate != null) {
            final parsed = DateTime.tryParse(rawDate.replaceAll('/', '-'));
            if (parsed != null) {
              expenseDate = parsed;
              break;
            }
          }
        }
      }

      if (totalAmount > 0) {
        return ExpenseModel(
          id: '',
          userId: userId,
          merchant: merchant,
          category: 'Food & Dining',
          totalAmount: totalAmount,
          currency: 'LKR',
          date: expenseDate,
          items: [],
        );
      }
    } catch (_) {}
    return null;
  }

  /// Parses and normalizes JSON string into ExpenseModel
  ExpenseModel _parseExpenseFromJson(String rawJson, String userId) {
    String cleanJson = rawJson.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    } else if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    final Map<String, dynamic> jsonData = jsonDecode(cleanJson);

    double parsedAmount = 0.0;
    final rawAmount = jsonData['totalAmount'];
    if (rawAmount is num) {
      parsedAmount = rawAmount.toDouble();
    } else if (rawAmount is String) {
      parsedAmount =
          double.tryParse(rawAmount.replaceAll(',', '').trim()) ?? 0.0;
    }

    return ExpenseModel(
      id: '',
      userId: userId,
      merchant: jsonData['merchant'] ?? 'Unknown Merchant',
      category: jsonData['category'] ?? 'Other',
      totalAmount: parsedAmount,
      currency: jsonData['currency'] ?? 'LKR',
      date: jsonData['date'] != null
          ? DateTime.tryParse(jsonData['date']) ?? DateTime.now()
          : DateTime.now(),
      items: (jsonData['items'] as List<dynamic>?)?.map((item) {
            final map = Map<String, dynamic>.from(item);
            double price = 0.0;
            final rawPrice = map['price'];
            if (rawPrice is num) {
              price = rawPrice.toDouble();
            } else if (rawPrice is String) {
              price =
                  double.tryParse(rawPrice.replaceAll(',', '').trim()) ?? 0.0;
            }
            return ExpenseItem(
              name: map['name'] ?? 'Item',
              price: price,
              quantity: (map['quantity'] as num?)?.toInt() ?? 1,
            );
          }).toList() ??
          [],
    );
  }
}
