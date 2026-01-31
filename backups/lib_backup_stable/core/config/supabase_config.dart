
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://pthiaalrizufhlplbjht.supabase.co';
  static const String anonKey = 'sb_publishable_fq738FQkpkE1ppEkJlwqGQ_YQf58fYU';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
