import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:planmapp/features/expenses/services/receipt_scanner_service.dart';
import 'receipt_scanner_interface.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:planmapp/core/config/api_config.dart';

class ReceiptScannerImplementation implements ReceiptScannerPlatform {
  @override
  Future<ParsedReceipt> scanReceipt(XFile imageFile) async {
    return await _scanWithGeminiDirect(imageFile);
  }

  Future<ParsedReceipt> _scanWithGeminiDirect(XFile imageFile) async {
      print(">>> WEB SCANNER: Starting Gemini-Pro Direct Call");
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

  @override
  void dispose() {}
}
