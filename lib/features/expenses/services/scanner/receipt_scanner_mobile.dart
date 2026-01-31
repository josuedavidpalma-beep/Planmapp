
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:planmapp/features/expenses/services/receipt_scanner_service.dart';
import 'receipt_scanner_interface.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:planmapp/core/config/api_config.dart';

class ReceiptScannerImplementation implements ReceiptScannerPlatform {
  static const bool _useGemini = true; 

  @override
  Future<ParsedReceipt> scanReceipt(XFile imageFile) async {
    final file = File(imageFile.path);
    if (_useGemini) {
      try {
        final result = await _scanWithGemini(file);
        if (result.items.isNotEmpty || (result.total ?? 0) > 0) return result;
      } catch (e) {
        print("Gemini Failed: $e. Falling back to ML Kit.");
      }
    }
    return await _scanWithLocalMLKit(file);
  }

  // --- Gemini Implementation ---
  Future<ParsedReceipt> _scanWithGemini(File imageFile) async {
      print(">>> MOBILE SCANNER: Starting Gemini-Pro Call");
      final model = GenerativeModel(model: 'gemini-pro', apiKey: ApiConfig.geminiApiKey);
      final imageBytes = await imageFile.readAsBytes();

      final prompt = Content.multi([
          TextPart("Analyze this receipt image. Extract items, prices, quantities, and totals. "
                   "Ignore dates, addresses, or phone numbers. "
                   "Return ONLY a valid JSON object with this structure: "
                   "{ \"items\": [{\"name\": \"string\", \"qty\": int, \"price\": double}], \"tip\": double, \"tax\": double, \"total\": double } "
                   "If a value is not found, use 0. Do not use Markdown formatting (no ```json). Just the raw JSON string."),
          DataPart('image/jpeg', imageBytes),
      ]);

      final response = await model.generateContent([prompt]);
      final text = response.text;
      
      if (text == null) throw Exception("Empty response from AI");

      // Clean cleanup just in case (e.g. if it adds backticks)
      final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
      
      final Map<String, dynamic> data = jsonDecode(cleanJson);
      
      List<ParsedItem> items = [];
      if (data['items'] != null) {
          for (var i in data['items']) {
              items.add(ParsedItem(
                  name: i['name']?.toString() ?? 'Item', 
                  price: double.tryParse(i['price']?.toString() ?? '0') ?? 0.0, 
                  quantity: int.tryParse(i['qty']?.toString() ?? '1') ?? 1
              ));
          }
      }

      return ParsedReceipt(
          items: items,
          total: double.tryParse(data['total']?.toString() ?? ''),
          tip: double.tryParse(data['tip']?.toString() ?? ''),
          tax: double.tryParse(data['tax']?.toString() ?? ''),
      );
  }

  // --- Local Fallback (ML Kit) ---
  Future<ParsedReceipt> _scanWithLocalMLKit(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return _parseRawTextSmart(recognizedText.text);
    } catch (e) {
      print("Local OCR Error: $e");
      return ParsedReceipt(items: [], total: 0);
    } finally {
      textRecognizer.close();
    }
  }

  // ... (Identical helper methods for ML Kit Parsing kept for fallback) ...
  ParsedReceipt _parseRawTextSmart(String fullText) {
    List<ParsedItem> items = [];
    double? foundTotal;
    
    final lines = fullText.split('\n');
    for (var line in lines) {
       line = line.trim();
       if (line.isEmpty) continue;
       if (_isLikelyItem(line)) {
           final extracted = _extractItemFromLine(line);
           if (extracted != null) items.add(extracted);
       }
       if (line.toLowerCase().contains("total") && !line.toLowerCase().contains("sub")) {
           final nums = _extractNumbers(line);
           if (nums.isNotEmpty) foundTotal = nums.reduce(max);
       }
    }

    return ParsedReceipt(items: items, total: foundTotal);
  }

  bool _isLikelyItem(String line) {
     if (line.length < 4) return false;
     final lower = line.toLowerCase();
     if (lower.contains("fecha") || lower.contains("nit") || lower.contains("total")) return false;
     return RegExp(r'[\d\.,]+').hasMatch(line);
  }

  ParsedItem? _extractItemFromLine(String line) {
      try {
        String clean = line.replaceAll(r'$', '').trim();
        final match = RegExp(r'^(\d+\s+)?(.+?)(\s+[\d\.,]+)$').firstMatch(clean);
        if (match != null) {
           int qty = 1;
           if (match.group(1) != null) {
              qty = int.tryParse(match.group(1)!.trim()) ?? 1;
           }
           String name = match.group(2)!.trim();
           double price = _parsePrice(match.group(3)!.trim());
           return ParsedItem(name: name, price: price, quantity: qty);
        }
        return null;
      } catch (e) { return null; }
  }

  double _parsePrice(String raw) {
      String clean = raw.replaceAll(RegExp(r'[^\d\.,]'), '').replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(clean) ?? 0.0;
  }
  
  List<double> _extractNumbers(String line) {
     final matches = RegExp(r'[\d\.,]+').allMatches(line);
     return matches.map((m) => _parsePrice(m.group(0)!)).toList();
  }

  @override
  void dispose() {}
}
