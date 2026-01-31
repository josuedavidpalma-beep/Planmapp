import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';

import 'package:planmapp/core/services/auth_service.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _handleEntry(BuildContext context) async {
    // Debug: Show we are starting
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conectando con Supabase...')),
    );

    try {
      final authService = AuthService();
      await authService.signInAnonymously();
      
      // Debug: Success, show ID
      final userId = authService.currentUser?.id;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('¡Éxito! ID creado: $userId')),
        );
        // Wait a bit so user can read the ID before navigating
        await Future.delayed(const Duration(seconds: 2)); 
        if (context.mounted) {
          context.go('/');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error CRÍTICO: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showTerms(BuildContext context) {
    _showTermsModal(context, onAccepted: () => _handleEntry(context));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      // ... (Rest of UI)
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBrand,
              AppTheme.secondaryBrand,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Text(
                  'Planmapp',
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Planes que sí suceden.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 3),
                
                _buildSocialButton(
                  context, 
                  label: "Continuar con Google", 
                  icon: Icons.g_mobiledata, 
                  onTap: () => _showTerms(context), 
                ),
                const SizedBox(height: 16),
                _buildSocialButton(
                  context, 
                  label: "Usar número de teléfono", 
                  icon: Icons.phone_iphone, 
                  onTap: () => _showTerms(context), 
                ),
                
                const SizedBox(height: 32),
                
                OutlinedButton(
                  onPressed: () => _showTerms(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Entrar como Invitado',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showTerms(context),
                  child: Text(
                    'Al continuar, aceptas nuestros términos y política de datos.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                      decoration: TextDecoration.underline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsModal(BuildContext context, {required VoidCallback onAccepted}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // Force interaction
      enableDrag: false,    // Force interaction
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85, // Taller to show content
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column( // Use Column to keep button at bottom
            children: [
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Text(
                      "Términos y Privacidad",
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBrand
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildLegalSection(
                      context,
                      "Importante (Habeas Data)",
                      "Para protegerte, necesitamos que aceptes explícitamente:"
                    ),
                    const SizedBox(height: 20),
                    _buildLegalSection(
                      context,
                      "1. Uso de Datos (Ley 1581)",
                      "Autorizas el uso de tu teléfono y contactos SOLO para: Sincronizar amigos, Notificaciones de eventos y Sugerencias locales (B2B)."
                    ),
                    const SizedBox(height: 20),
                    _buildLegalSection(
                      context,
                      "2. Responsabilidad Financiera",
                      "Planmapp es una herramienta informativa. NO custodiamos dinero. La gestión de fondos vía Wompi/Nequi es responsabilidad exclusiva del organizador."
                    ),
                   const SizedBox(height: 20),
                   _buildLegalSection(
                      context,
                      "Control Total",
                      "Puedes revocar estos permisos en cualquier momento desde Configuración."
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => context.pop(), // Cancel
                      child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        context.pop(); // Close modal
                        onAccepted();  // Enter App
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBrand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text("Aceptar y Continuar"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(color: Colors.black87, height: 1.5)),
      ],
    );
  }

  Widget _buildSocialButton(BuildContext context, {
    required String label, 
    required IconData icon, 
    required VoidCallback onTap
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: AppTheme.primaryBrand),
      label: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryBrand,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryBrand,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
      ),
    );
  }
}

