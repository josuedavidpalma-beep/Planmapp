
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

  // Sign Up with Email
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // Sign In with Email
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  // Sign In with Google (Native Flow)
  Future<bool> signInWithGoogle() async {
    // NOTE: This requires 'google_sign_in' package and native configuration
    // For now, we return false as we need to configure the native side first.
    // Real implementation involves getting idToken from GoogleSignIn and passing to Supabase.
    try {
        await _supabase.auth.signInWithOAuth(OAuthProvider.google, redirectTo: 'io.supabase.flutterqa://login-callback/');
        return true; 
    } catch(e) {
        print("Google Sign In Error: $e");
        return false;
    }
  }

  // Reset Password for Email
  Future<void> resetPasswordForEmail(String email) async {
    // Redirection to Deep Link scheme defined in AndroidManifest
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'io.planmapp.app://reset-callback/',
    );
  }

  // Sign Out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
