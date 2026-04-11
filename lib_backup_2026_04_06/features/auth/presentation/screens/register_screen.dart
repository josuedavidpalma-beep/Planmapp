import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/services/auth_service.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phonePasswordController = TextEditingController();
  
  bool _isLoading = false;

  Future<void> _registerEmail() async {
    setState(() => _isLoading = true);
    try {
      final response = await AuthService().signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      
      if (mounted) {
         if (response.user != null) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Cuenta creada!")));
             context.go('/onboarding-setup');
         }
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro por teléfono próximamente (Fase Beta)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fallback
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
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     // LOGO / BRANDING
                     const Icon(Icons.person_add_rounded, size: 64, color: AppTheme.primaryBrand)
                          .animate().fade().scale(),
                     const SizedBox(height: 16),
                     Text(
                       "Planmapp", 
                       style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)
                     ).animate().fade().slideY(begin: 0.2, end: 0),
                     Text(
                       "Organiza sin estrés.", 
                       style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)
                     ).animate().fade(delay: 200.ms),
                     
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
                                         TabBar(
                                           dividerColor: Colors.transparent,
                                           indicatorColor: AppTheme.primaryBrand,
                                           labelColor: AppTheme.primaryBrand,
                                           unselectedLabelColor: Colors.white60,
                                           tabs: const [
                                             Tab(text: "Correo"),
                                             Tab(text: "Teléfono"),
                                           ],
                                         ),
                                         const SizedBox(height: 24),
                                         SizedBox(
                                           height: 250, // Fixed height for tabs
                                           child: TabBarView(
                                             children: [
                                               // TAB 1: EMAIL
                                               Column(
                                                 children: [
                                                   TextField(
                                                      controller: _emailController,
                                                      style: const TextStyle(color: Colors.white),
                                                      decoration: const InputDecoration(
                                                          labelText: "Correo Electrónico", 
                                                          prefixIcon: Icon(Icons.email_outlined),
                                                      ),
                                                   ),
                                                   const SizedBox(height: 16),
                                                   TextField(
                                                      controller: _passwordController,
                                                      style: const TextStyle(color: Colors.white),
                                                      decoration: const InputDecoration(
                                                          labelText: "Contraseña", 
                                                          prefixIcon: Icon(Icons.lock_outlined)
                                                      ),
                                                      obscureText: true,
                                                   ),
                                                   const SizedBox(height: 32),
                                                   SizedBox(
                                                     width: double.infinity,
                                                     child: ElevatedButton(
                                                       onPressed: _isLoading ? null : _registerEmail,
                                                       child: _isLoading 
                                                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                                                          : const Text("Registrarme"),
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                               // TAB 2: PHONE
                                               Column(
                                                 children: [
                                                   TextField(
                                                      controller: _phoneController,
                                                      style: const TextStyle(color: Colors.white),
                                                      keyboardType: TextInputType.phone,
                                                      decoration: const InputDecoration(
                                                          labelText: "Número de Teléfono", 
                                                          prefixIcon: Icon(Icons.phone_iphone),
                                                      ),
                                                   ),
                                                   const SizedBox(height: 16),
                                                   TextField(
                                                      controller: _phonePasswordController,
                                                      style: const TextStyle(color: Colors.white),
                                                      decoration: const InputDecoration(
                                                          labelText: "Contraseña", 
                                                          prefixIcon: Icon(Icons.lock_outlined)
                                                      ),
                                                      obscureText: true,
                                                   ),
                                                   const SizedBox(height: 32),
                                                   SizedBox(
                                                     width: double.infinity,
                                                     child: ElevatedButton(
                                                       onPressed: _isLoading ? null : _showComingSoon,
                                                       child: const Text("Registrarme"),
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                             ],
                                           ),
                                         )
                                     ],
                                 ),
                             ),
                         ),
                     ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),

                     const SizedBox(height: 24),
                     TextButton(
                        onPressed: () => context.go('/login'),
                        child: RichText(
                            text: TextSpan(
                                text: "¿Ya tienes cuenta? ",
                                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                children: const [
                                    TextSpan(text: "Inicia Sesión", style: TextStyle(color: AppTheme.primaryBrand, fontWeight: FontWeight.bold))
                                ]
                            )
                        ),
                     ).animate().fade(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
