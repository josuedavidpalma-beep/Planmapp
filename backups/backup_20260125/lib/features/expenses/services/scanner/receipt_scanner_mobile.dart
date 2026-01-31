
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:planmapp/features/expenses/services/receipt_scanner_service.dart';
import 'receipt_scanner_interface.dart';

class ReceiptScannerImplementation implements ReceiptScannerPlatform {
  static const bool _useEdgeFunction = true; 

  @override
  Future<ParsedReceipt> scanReceipt(XFile imageFile) async {
    final file = File(imageFile.path);
    if (_useEdgeFunction) {
      try {
        final result = await _scanWithEdgeFunction(file);
        if (result.items.isNotEmpty) return result;
      } catch (e) {
        print("Edge Function Failed: $e");
      }
    }
    return await _scanWithLocalMLKit(file);
  }

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

  // --- Secure Edge Function Implementation ---
  Future<ParsedReceipt> _scanWithEdgeFunction(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);

    // Call Supabase Edge Function 'analyze-receipt'
    final response = await Supabase.instance.client.functions.invoke(
      'analyze-receipt',
      body: {'image_base64': base64Image},
    );
    
    // Check for function error
    if (response.status != 200) {
       // Try to parse error message if JSON
       String authError = "";
       try {
          // If it's a map, grab 'error' field. If string, just use it.
          authError = response.data is Map ? response.data['error'] : response.data.toString();
       } catch(_) {
          authError = "Status ${response.status}";
       }
       throw Exception('AI Error: $authError');
    }

    final jsonMap = response.data; // Invoke returns dynamic/Map directly for JSON responses

    // Parse Items (Section A) 
    final List<dynamic> itemsJson = jsonMap['section_A_items'] ?? [];
    
    // Note: The Edge Function already handles the "Strict Sanitization", "Nuclear Option", 
    // and "Fusion Rule". We just need to map the clean JSON result.
    final List<ParsedItem> paramsItems = itemsJson.map((i) => ParsedItem(
        name: i['descripcion']?.toString() ?? "Item",
        price: double.tryParse(i['valor_unitario']?.toString() ?? "") ?? 0.0,
        quantity: num.tryParse(i['cantidad']?.toString() ?? "1")?.toInt() ?? 1
    )).toList();

    // Parse Additionals (Section B)
    double tip = 0;
    double discount = 0;
    double tax = 0;

    final List<dynamic> additionals = jsonMap['section_B_additionals'] ?? [];
    for (var adj in additionals) {
       final type = adj['type']?.toString().toLowerCase() ?? "";
       final val = double.tryParse(adj['valor']?.toString() ?? "") ?? 0.0;
       
       if (type.contains('tip') || type.contains('propina') || type.contains('service')) tip += val;
       else if (type.contains('discount') || type.contains('descuento')) discount += val;
       else if (type.contains('tax') || type.contains('impuesto')) tax += val;
    }

    double finalTotal = 0;
    final metadata = jsonMap['metadata'];
    if (metadata != null && metadata['total_pagado'] != null) {
        finalTotal = double.tryParse(metadata['total_pagado'].toString()) ?? 0.0;
    }

    if (finalTotal == 0) {
         for (var i in paramsItems) finalTotal += (i.price * i.quantity);
         finalTotal = finalTotal + tip + tax - discount;
    }

    return ParsedReceipt(
       items: paramsItems, 
       total: finalTotal,
       tip: tip,
       discount: discount,
       tax: tax
    );
  }

  // --- Local Fallback Logic ---
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
