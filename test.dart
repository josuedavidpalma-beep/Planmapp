import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final url = 'https://pthiaalrizufhlplbjht.supabase.co/rest/v1/expenses?select=title,created_by,profiles:created_by(full_name)&limit=1';
  final key = '***';
  
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse(url));
  req.headers.add('apikey', key);
  req.headers.add('Authorization', 'Bearer $key');
  
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print(body);
}
