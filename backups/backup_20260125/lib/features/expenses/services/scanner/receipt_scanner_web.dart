
import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/features/expenses/services/receipt_scanner_service.dart';
import 'receipt_scanner_interface.dart';

class ReceiptScannerImplementation implements ReceiptScannerPlatform {
  @override
  Future<ParsedReceipt> scanReceipt(XFile imageFile) async {
    return await _scanWithEdgeFunction(imageFile);
  }

  Future<ParsedReceipt> _scanWithEdgeFunction(XFile imageFile) async {
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

  @override
  void dispose() {}
}
