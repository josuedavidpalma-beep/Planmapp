import 'dart:convert';
import 'package:http/http.dart' as http;
import 'core/config/api_config.dart';

void main() async {
  try {
    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=${ApiConfig.geminiApiKey}');
    final response = await http.get(url);
    
    // Formatear la salida para que sea fácil de leer
    var decoded = jsonDecode(response.body);
    var encoder = JsonEncoder.withIndent('  ');
    print(encoder.convert(decoded));
  } catch (e) {
    print('Error: $e');
  }
}
