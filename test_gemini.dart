import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = 'AIzaSyBlD-7lLs1s24e1bCEJ9rP6BNTcEjAYnTw';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
  
  final response = await http.get(url);
  print('Status code: ${response.statusCode}');
  
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final models = data['models'] as List;
    print('Available models:');
    for (var model in models) {
      final name = model['name'];
      final support = model['supportedGenerationMethods'];
      if (name.toString().contains('flash')) {
        print('- $name (supports: $support)');
      }
    }
  } else {
    print('Error: ${response.body}');
  }
}
