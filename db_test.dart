import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final urlStr = 'https://pthiaalrizufhlplbjht.supabase.co/rest/v1/payment_trackers?select=id,plan_id,bill_id,user_id,guest_name,amount_owe,amount_paid,status,description,created_at,plans(creator_id)&limit=10';
  final key = '***';
  
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse(urlStr));
  req.headers.add('apikey', key);
  req.headers.add('Authorization', 'Bearer $key');
  
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  print('--- Payment Trackers ---');
  print(body);
  
  final url2 = 'https://pthiaalrizufhlplbjht.supabase.co/rest/v1/expenses?limit=5';
  final req2 = await client.getUrl(Uri.parse(url2));
  req2.headers.add('apikey', key);
  req2.headers.add('Authorization', 'Bearer $key');
  
  final res2 = await req2.close();
  final body2 = await res2.transform(utf8.decoder).join();
  print('--- Expenses ---');
  print(body2);
}
