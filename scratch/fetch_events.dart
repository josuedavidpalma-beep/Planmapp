import 'dart:io';
import 'dart:convert';

void main() async {
  final supabaseUrl = 'https://pthiaalrizufhlplbjht.supabase.co';
  
  // Try to find the anon key in lib/core/constants/ or lib/main.dart or .env
  final envFile = File('.env');
  String? anonKey;
  if (await envFile.exists()) {
    final lines = await envFile.readAsLines();
    for (var line in lines) {
      if (line.startsWith('SUPABASE_ANON_KEY=')) {
        anonKey = line.split('=')[1].trim();
      }
    }
  }
  
  if (anonKey == null) {
      print("Could not find SUPABASE_ANON_KEY in .env");
      return;
  }

  print("Fetching events...");
  final url = Uri.parse('$supabaseUrl/rest/v1/local_events?status=eq.pending&select=*');
  final request = await HttpClient().getUrl(url);
  request.headers.add('apikey', anonKey);
  request.headers.add('Authorization', 'Bearer $anonKey');
  final response = await request.close();
  
  final stringData = await response.transform(utf8.decoder).join();
  print("Status: ${response.statusCode}");
  print("Data: $stringData");
}
