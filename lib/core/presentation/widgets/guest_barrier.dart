import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/services/auth_service.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class GuestBarrier {
  /// Wraps an action. If the user is a guest, it blocks the action and shows a registration prompt.
  /// If the user is registered, it executes `onAllowed`.
  static void protect(BuildContext context, VoidCallback onAllowed) {
    if (AuthService().isAnonymous) {
      _showRegistrationPrompt(context);
    } else {
      onAllowed();
    }
  }

  static void _showRegistrationPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_rounded, size: 64, color: AppTheme.secondaryBrand),
              const SizedBox(height: 16),
              const Text(
                "Función Restringida",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Para guardar tu progreso, crear nuevos planes y disfrutar de todas las herramientas, necesitas crear una cuenta gratuita.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBrand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    context.pop(); // Close modal
                    // Navigate to auth (login clears the guest session)
                    context.go('/onboarding');
                  },
                  child: const Text("Crear mi Cuenta Ahora"),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text("Seguir Explorando", style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        );
      },
    );
  }
}
