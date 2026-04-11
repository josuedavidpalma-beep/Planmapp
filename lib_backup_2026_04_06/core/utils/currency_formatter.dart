import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter;

  CurrencyInputFormatter({String locale = 'es_CO'})
      : _formatter = NumberFormat.decimalPattern(locale);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // 1. Remove non-digits
    final newText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // 2. Parse to integer
    if (newText.isEmpty) {
        return newValue.copyWith(text: '');
    }
    
    final intValue = int.tryParse(newText) ?? 0;

    // 3. Format
    final newString = _formatter.format(intValue);

    // 4. Calculate cursor position
    // Simple logic: maintain cursor at end or try to preserve relative?
    // For currency, usually nice to keep at end if appending.
    
    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
  
  // Static helper to parse back to double
  static double parse(String formatted) {
      if (formatted.isEmpty) return 0.0;
      return double.tryParse(formatted.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
  }

  // Static helper to format for display
  static String format(double value, {String locale = 'es_CO', String symbol = '\$'}) {
      final formatter = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: 0);
      return formatter.format(value);
  }
}
