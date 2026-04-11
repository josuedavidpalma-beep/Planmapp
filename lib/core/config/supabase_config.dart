
import 'package:supabase_flutter/supabase_flutter.dart';
// ApiConfig is generated at build time by GitHub Actions CI/CD
// It is NOT stored in the repository - see .github/workflows/deploy.yml
// For local development, create lib/core/config/api_config.dart manually (it's in .gitignore)
import 'package:planmapp/core/config/api_config.dart';

class SupabaseConfig {
  static String get url => ApiConfig.supabaseUrl;
  static String get anonKey => ApiConfig.supabaseAnonKey;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
}
