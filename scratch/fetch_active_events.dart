import 'dart:io';
import 'dart:convert';

void main() async {
  final supabaseUrl = 'https://pthiaalrizufhlplbjht.supabase.co';
  
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

  print("Fetching active events...");
  final url = Uri.parse('$supabaseUrl/rest/v1/local_events?status=eq.active&select=id,event_name,image_url,primary_source');
  final request = await HttpClient().getUrl(url);
  request.headers.add('apikey', anonKey);
  request.headers.add('Authorization', 'Bearer $anonKey');
  final response = await request.close();
  
  final stringData = await response.transform(utf8.decoder).join();
  print("Status: ${response.statusCode}");
  
  try {
      final List<dynamic> data = jsonDecode(stringData);
      print("Total active events: ${data.length}");
      for (var item in data) {
          print("- ${item['event_name']} | Image: ${item['image_url'] != null && item['image_url'].toString().isNotEmpty ? 'YES' : 'NO'} | Link: ${item['primary_source']}");
          if (item['image_url'] == null || item['image_url'].toString().isEmpty) {
              print("  [MISSING IMAGE FOR THIS EVENT]");
          }
      }
  } catch (e) {
      print("Error decoding: $stringData");
  }
}
