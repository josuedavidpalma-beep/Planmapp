import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class AuthGuard extends StatelessWidget {
  final Widget child;
  final String? restrictedMessage; // Optional custom message

  const AuthGuard({
    super.key, 
    required this.child,
    this.restrictedMessage,
  });

  bool get _isGuest {
    if (isTestMode) return false; // Treat as authenticated in test mode
    final user = Supabase.instance.client.auth.currentUser;
    return user == null || user.isAnonymous;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
          if (_isGuest) {
             _showRestrictedDialog(context);
          } else {
             // If child is just a visual wrapper, this tap might block child taps?
             // Actually, this approach wraps a button usually.
             // Better approach: This widget intercepts taps if guest? 
             // Or maybe we use an "ActionGuard" style where we wrap the callback?
          }
      },
      // This simple wrapper might interfere with child gestures if child is a Button.
      // Better Pattern: "ProtectAction" mixin or wrapper that takes a builder or callback.
      child: child,
    );
  }
  
  // Static helper for cleaner usage in callbacks
  // STATIC FLAG FOR TESTING
  static bool isTestMode = true;

  static Future<bool> ensureAuthenticated(BuildContext context) async {
      if (isTestMode) return true; // BYPASS FOR TESTING

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
          _showRestrictedDialog(context);
          return false;
      }
      return true;
  }

  static void _showRestrictedDialog(BuildContext context) {
      showDialog(
          context: context,
          builder: (c) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                          BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
                      ]
                  ),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: AppTheme.primaryBrand.withOpacity(0.1),
                                  shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.rocket_launch, size: 40, color: AppTheme.primaryBrand),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                              "¡Únete al Plan!",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87),
                              textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                              "El modo invitado es genial para mirar, pero para votar, chatear y dividir gastos necesitas tu propia cuenta.",
                              style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                              textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryBrand,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                  ),
                                  onPressed: () {
                                      Navigator.pop(c);
                                      context.go('/welcome'); 
                                  }, 
                                  child: const Text("Crear mi cuenta gratis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                              ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                              onPressed: ()=>Navigator.pop(c), 
                              child: const Text("Solo mirar por ahora", style: TextStyle(color: Colors.grey))
                          ),
                      ],
                  ),
              ),
          ),
      );
  }
}
