import 'dart:convert';
import 'package:http/http.dart' as http;
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
      print(">>> WEB SCANNER: Llamando a Gemini-2.5-Flash via HTTP POST");
      final apiKey = ApiConfig.geminiApiKey;
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      final String mimeType = imageFile.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      final String promptText = "Analiza esta imagen de una factura/recibo de Colombia. Extrae los ítems consumidos con su precio final, y los valores totales de la cuenta.\n\n"
                        "ROL DEL SISTEMA: Eres un motor OCR de precisión para facturas. Usa la 'ESTRATEGIA DE SUSTRACCIÓN':\n"
                        "1. Detectar números: Identifica primero PRECIO y CANTIDAD. Sustrae esos números de la línea.\n"
                        "2. El sobrante: Lo que queda es la DESCRIPCIÓN del ítem. Si el sobrante es vacío, busca texto en la línea de arriba.\n\n"
                        "REGLAS DE BLOQUEO Y DESCUENTOS:\n"
                        "- Si detectas un 'Descuento' global en la factura, prorratea (resta) ese valor matemáticamente del precio de cada ítem para que el subtotal real coincida.\n"
                        "- Nunca crees un ítem o producto llamado 'Descuento'.\n"
                        "- Si el campo 'name' o descripción contiene solo números o símbolos, ignora la línea (es un ítem inválido).\n\n"
                        "Aplica estas reglas del contexto colombiano:\n"
                        "- 'subtotal': Corresponde a la suma de los productos antes de impuestos y propina.\n"
                        "- 'tax': Es el impuesto cobrado, usualmente dice 'Impoconsumo (8%)' o 'IVA (19%)'.\n"
                        "- 'tip': Es la propina voluntaria, usualmente el 10% del subtotal.\n"
                        "- 'total': Es la suma de subtotal + tax + tip.\n"
                        "Ignora fechas, direcciones o teléfonos.\n\n"
                        "Devuelve ÚNICAMENTE un objeto JSON válido con esta estructura estricta: "
                        "{ \"items\": [{\"name\": \"string\", \"qty\": int, \"price\": double}], \"subtotal\": double, \"tip\": double, \"tax\": double, \"total\": double }\n"
                        "Si un valor no se encuentra en el papel, infiérelo matemáticamente si es posible o devuélvelo como 0. No uses formato Markdown. Solo el texto JSON.";

      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey');
      
      try {
        final httpResponse = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [{
              "parts": [
                {"text": promptText},
                {
                  "inlineData": {
                    "mimeType": mimeType,
                    "data": base64Image
                  }
                }
              ]
            }],
            "safetySettings": [
                {"category": "HARM_CATEGORY_HARASSMENT", "threshold": "BLOCK_NONE"},
                {"category": "HARM_CATEGORY_HATE_SPEECH", "threshold": "BLOCK_NONE"}
            ],
            "generationConfig": { "temperature": 0.1 }
          })
        );

        if (httpResponse.statusCode != 200) {
          throw Exception("HTTP Error: ${httpResponse.statusCode} - ${httpResponse.body}");
        }
        
        final responseData = jsonDecode(httpResponse.body);
        final text = responseData['candidates']?[0]?['content']?['parts']?[0]?['text'];
        
        if (text == null) throw Exception("La IA no devolvió texto");

        final startIndex = text.indexOf('{');
        final endIndex = text.lastIndexOf('}');
        if (startIndex == -1 || endIndex == -1) throw Exception("JSON no encontrado en respuesta");
        
        final cleanJson = text.substring(startIndex, endIndex + 1);
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
            subtotal: double.tryParse(data['subtotal']?.toString() ?? ''),
            total: double.tryParse(data['total']?.toString() ?? ''),
            tip: double.tryParse(data['tip']?.toString() ?? ''),
            tax: double.tryParse(data['tax']?.toString() ?? ''),
        );
      } catch (e) {
        print("Error específico en la llamada a Gemini Web HTTP: $e");
        rethrow;
      }
  }

  @override
  void dispose() {}
}
