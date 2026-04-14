
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  // --- Edge Function Implementation ---
  Future<ParsedReceipt> _scanWithGemini(File imageFile) async {
      print(">>> MOBILE SCANNER: Llamando a Supabase Edge Function (analyze-receipt)");
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      try {
        final response = await Supabase.instance.client.functions.invoke(
          'analyze-receipt',
          body: {'image_base64': base64Image},
        );

        final data = response.data;
        if (data == null) throw Exception("La función Edge no devolvió datos");
        
        List<ParsedItem> items = [];
        if (data['section_A_items'] != null) {
            for (var i in data['section_A_items']) {
                items.add(ParsedItem(
                    name: i['descripcion']?.toString() ?? 'Item', 
                    price: double.tryParse(i['valor_unitario']?.toString() ?? '0') ?? 0.0, 
                    quantity: double.tryParse(i['cantidad']?.toString() ?? '1')?.toInt() ?? 1
                ));
            }
        }

        double tip = 0;
        double tax = 0;
        if (data['section_B_additionals'] != null) {
            for (var b in data['section_B_additionals']) {
                if (b['type'] == 'Tip') tip += double.tryParse(b['valor']?.toString() ?? '0') ?? 0;
                if (b['type'] == 'Tax') tax += double.tryParse(b['valor']?.toString() ?? '0') ?? 0;
            }
        }

        double total = double.tryParse(data['metadata']?['total_pagado']?.toString() ?? '0') ?? 0.0;

        return ParsedReceipt(
            items: items,
            subtotal: 0,
            total: total,
            tip: tip,
            tax: tax,
        );
      } catch (e) {
        print("Error específico en la llamada a Supabase analyze-receipt Mobile: $e");
        rethrow;
      }
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
        // Se eliminan símbolos de moneda comunes y múltiples espacios para estandarizar
        String clean = line.replaceAll(RegExp(r'[\$]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
        
        // Regex mejorada: Soporta cantidad opcional, descripción alfanumérica y precio al final.
        // Maneja casos donde el OCR no lee correctamente los espacios entre texto y números.
        final match = RegExp(r'^([\d.,]+\s+)?(.+?)\s*([\d\.,]+)$').firstMatch(clean);
        
        if (match != null) {
           int qty = 1;
           if (match.group(1) != null) {
              String qtyStr = match.group(1)!.replaceAll(RegExp(r'[^\d]'), '');
              qty = int.tryParse(qtyStr) ?? 1;
           }
           String name = match.group(2)!.trim();
           // Descartar si el nombre no contiene al menos letras (evitar capturar líneas solo con números)
           if (!RegExp(r'[a-zA-Z]').hasMatch(name)) return null;

           double price = _parsePrice(match.group(3)!.trim());
           if (price == 0) return null;

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
