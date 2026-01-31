
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sign in anonymously (Guest Mode)
  Future<void> signInAnonymously() async {
    try {
      await _supabase.auth.signInAnonymously();
    } catch (e) {
      throw Exception('Error al iniciar sesión como invitado: $e');
    }
  }

  // Check if user is logged in
  User? get currentUser => _supabase.auth.currentUser;

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
