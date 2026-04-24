import 'dart:convert';
import 'package:cross_file/cross_file.dart';
import 'package:planmapp/features/expenses/services/receipt_scanner_service.dart';
import 'receipt_scanner_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceiptScannerImplementation implements ReceiptScannerPlatform {
  @override
  Future<ParsedReceipt> scanReceipt(XFile imageFile, {bool isQuote = false}) async {
    return await _scanWithGeminiDirect(imageFile, isQuote: isQuote);
  }

  Future<ParsedReceipt> _scanWithGeminiDirect(XFile imageFile, {bool isQuote = false}) async {
      print(">>> WEB SCANNER: Llamando a Supabase Edge Function");
      final imageBytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      
      try {
        final endpoint = isQuote ? 'analyze-quote' : 'analyze-receipt';
        final response = await Supabase.instance.client.functions.invoke(
          endpoint,
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
        print("Error específico en la llamada a Supabase analyze-receipt Web: $e");
        rethrow;
      }
  }

  @override
  void dispose() {}
}
