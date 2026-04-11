import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class OnboardingSetupScreen extends StatefulWidget {
  const OnboardingSetupScreen({super.key});

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
          // Upsert profile
          await Supabase.instance.client.from('profiles').upsert({
              'id': user.id,
              'full_name': name,
              'display_name': name.split(' ')[0], // First name as display
              'updated_at': DateTime.now().toIso8601String(),
          });
          if (mounted) context.go('/'); // Go to Home
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fallback
      appBar: AppBar(
        title: const Text("Completa tu Perfil"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. BACKGROUND GRADIENT
          Positioned.fill(
              child: Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                              Color(0xFF0F111A), // Deep Dark
                              Color(0xFF1A1F2E), 
                              Color(0xFF0D0F14), // Very Dark
                          ]
                      )
                  ),
              )
          ),
          
          // 2. ORBS / GLOW (Decoration)
          Positioned(
              top: -100,
              left: -50,
              child: Container(
                  width: 300, height: 300,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      color: AppTheme.primaryBrand.withOpacity(0.4),
                      boxShadow: [BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.4), blurRadius: 100, spreadRadius: 50)]
                  ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: 0, end: 50, duration: 4.seconds)
          ),
          Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                  width: 250, height: 250,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, 
                      color: AppTheme.secondaryBrand.withOpacity(0.3),
                      boxShadow: [BoxShadow(color: AppTheme.secondaryBrand.withOpacity(0.3), blurRadius: 100, spreadRadius: 40)]
                  ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.2,1.2), duration: 5.seconds)
          ),

          // 3. CONTENT
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  const CircleAvatar(
                      radius: 50, 
                      backgroundColor: Colors.white12, 
                      child: Icon(Icons.person, size: 50, color: Colors.grey)
                  ).animate().fade().scale(),
                  const SizedBox(height: 8),
                  const Text("Sube una foto (Próximamente)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 48),
                  
                  // GLASS CARD FORM
                  ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 1)
                              ),
                              child: Column(
                                  children: [
                                      TextField(
                                        controller: _nameController,
                                        style: const TextStyle(color: Colors.white),
                                        decoration: const InputDecoration(
                                            labelText: "¿Cómo te llamas?", 
                                            helperText: "Para que tus amigos te reconozcan en los planes.",
                                            helperStyle: TextStyle(color: Colors.white54),
                                            prefixIcon: Icon(Icons.badge_outlined)
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _saveProfile,
                                          style: ElevatedButton.styleFrom(
                                             padding: const EdgeInsets.all(16),
                                             backgroundColor: AppTheme.primaryBrand,
                                             foregroundColor: Colors.white
                                          ),
                                          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Continuar"),
                                        ),
                                      ),
                                  ],
                              ),
                          ),
                      ),
                  ).animate().fade(delay: 200.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
