
import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:planmapp/core/config/supabase_config.dart';

class ReceiptScannerService {
  // Use a Const for the API Key or fetch from Supabase/Env
  // TODO: User must provide a valid API Key. 
  // Ideally: SupabaseConfig.geminiApiKey or similiar.
  // For now we will use a placeholder or ask the user to input it.
  static const String _apiKey = "AIzaSyB9PhkXejEfeNJvjCk8U6mnY4MelD-ejIM"; 

  Future<ParsedReceipt> scanReceipt(File imageFile) async {
    if (_apiKey == "TU_API_KEY_DE_GEMINI_AQUI") {
        // Fallback or Error if no API Key
        // For MVP demo, users might not have one. 
        // We can keep the Mock fallback for now strictly for safety if they don't set it.
    }

    try {
        final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
        final imageBytes = await imageFile.readAsBytes();
        
        final prompt = TextPart("""
            Analiza esta imagen de una factura/recibo. 
            Extrae los ítems comprados y el precio total.
            Ignora impuestos, subtotales o propinas en la lista de ítems, solo quiero los productos.
            Devuelve un JSON puro sin markdown, con este formato:
            {
              "items": [
                {"name": "Nombre del producto", "price": 10000}
              ],
              "total": 50000
            }
            Asegúrate de que los precios sean numéricos (double).
        """);

        final imagePart = DataPart('image/jpeg', imageBytes); // Assuming jpeg or handle mime type check
        
        final response = await model.generateContent([
            Content.multi([prompt, imagePart])
        ]);

        final text = response.text;
        if (text == null) throw Exception("No response from Gemini");

        // Clean Markdown if Gemini returns ```json ... ```
        final cleanText = text.replaceAll(RegExp(r'```json|```'), '').trim();
        final jsonMap = jsonDecode(cleanText);

        final List<dynamic> itemsJson = jsonMap['items'] ?? [];
        final List<ParsedItem> items = itemsJson.map((i) => ParsedItem(
            name: i['name'].toString(),
            price: double.tryParse(i['price'].toString()) ?? 0.0
        )).toList();

        final double? total = double.tryParse(jsonMap['total'].toString());

        return ParsedReceipt(items: items, total: total);

    } catch (e) {
        print("Gemini Error: $e");
        // Fallback to Mock or Empty
        return ParsedReceipt(items: [], total: 0);
    }
  }

  void dispose() {
    // No explicit close needed for Gemini Client usually http based
  }
}

class ParsedReceipt {
  final List<ParsedItem> items;
  final double? total;

  ParsedReceipt({required this.items, this.total});
}

class ParsedItem {
  final String name;
  final double price;

  ParsedItem({required this.name, required this.price});
}
