import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/services/auth_service.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planmapp/core/widgets/pwa_install_prompt.dart';
import 'package:flutter/foundation.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phonePasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscurePhonePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSecureCredentials();
  }

  Future<void> _loadSecureCredentials() async {
      try {
          final prefs = await SharedPreferences.getInstance();
          final email = prefs.getString('remember_email');
          final password = prefs.getString('remember_password');
          
          if (email != null && password != null && mounted) {
              setState(() {
                  _emailController.text = email;
                  _passwordController.text = password;
                  _rememberMe = true;
              });
          } else {
              // Always fill the last used email even if not remembering password
              final lastEmail = prefs.getString('last_email');
              if (lastEmail != null && mounted) {
                  setState(() { _emailController.text = lastEmail; });
              }
          }
      } catch (e) {
          // Fail silently
      }
  }

  Future<void> _loginEmail() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      // Siempre guardamos el último correo usado por conveniencia
      await prefs.setString('last_email', _emailController.text.trim());

      if (_rememberMe) {
          await prefs.setString('remember_email', _emailController.text.trim());
          await prefs.setString('remember_password', _passwordController.text.trim());
      } else {
          await prefs.remove('remember_email');
          await prefs.remove('remember_password');
      }

    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
        // Redirigir a la misma página actual si es posible, o a home
        final redirectUrl = kIsWeb ? Uri.base.origin : 'planmapp://login-callback';
        await Supabase.instance.client.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: redirectUrl,
        );
        // Nota: en la web, el redirect recargará la página.
    } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error con Google: $e'), backgroundColor: Colors.red));
        if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Acceso por teléfono próximamente (Fase Beta)')),
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
                     const Icon(Icons.rocket_launch_rounded, size: 64, color: AppTheme.primaryBrand)
                          .animate().fade().scale(),
                     const SizedBox(height: 16),
                     Text(
                       "Planmapp", 
                       style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)
                     ).animate().fade().slideY(begin: 0.2, end: 0),
                     Text(
                       "Bienvenido de vuelta", 
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
                                         // NEW: One-Click Google Login
                                         SizedBox(
                                           width: double.infinity,
                                           child: ElevatedButton.icon(
                                              icon: Image.network("https://img.icons8.com/color/48/google-logo.png", width: 24, height: 24),
                                              label: const Text("Continuar con Google", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                                              onPressed: _isLoading ? null : _loginWithGoogle,
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                              ),
                                           ),
                                         ),
                                         const SizedBox(height: 24),
                                         Row(
                                             children: [
                                                 Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                                                 Padding(
                                                     padding: const EdgeInsets.symmetric(horizontal: 8),
                                                     child: Text("O usa tu correo", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                                                 ),
                                                 Expanded(child: Divider(color: Colors.white.withOpacity(0.2))),
                                             ]
                                         ),
                                         const SizedBox(height: 24),

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
                                           height: 310, // Increased height for tabs
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
                                                      decoration: InputDecoration(
                                                          labelText: "Contraseña", 
                                                          prefixIcon: const Icon(Icons.lock_outlined),
                                                          suffixIcon: IconButton(
                                                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                                                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                                          ),
                                                      ),
                                                      obscureText: _obscurePassword,
                                                   ),
                                                   Row(
                                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                       children: [
                                                           Row(
                                                               children: [
                                                                   SizedBox(
                                                                       width: 24, height: 24,
                                                                       child: Checkbox(
                                                                           value: _rememberMe,
                                                                           activeColor: AppTheme.primaryBrand,
                                                                           side: const BorderSide(color: Colors.white60),
                                                                           onChanged: (val) {
                                                                               setState(() => _rememberMe = val ?? false);
                                                                           }
                                                                       )
                                                                   ),
                                                                   const SizedBox(width: 8),
                                                                   const Text("Recordar datos", style: TextStyle(color: Colors.white70, fontSize: 13)),
                                                               ]
                                                           ),
                                                           TextButton(
                                                             onPressed: () => context.push('/forgot-password'),
                                                             child: Text("¿Olvidaste tu contraseña?", style: TextStyle(color: AppTheme.primaryBrand.withOpacity(0.8), fontSize: 12)),
                                                           ),
                                                       ]
                                                   ),
                                                   const SizedBox(height: 16),
                                                   SizedBox(
                                                     width: double.infinity,
                                                     child: ElevatedButton(
                                                       onPressed: _isLoading ? null : _loginEmail,
                                                       child: _isLoading 
                                                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                                                          : const Text("Entrar"),
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
                                                      decoration: InputDecoration(
                                                          labelText: "Contraseña", 
                                                          prefixIcon: const Icon(Icons.lock_outlined),
                                                          suffixIcon: IconButton(
                                                              icon: Icon(_obscurePhonePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                                                              onPressed: () => setState(() => _obscurePhonePassword = !_obscurePhonePassword),
                                                          ),
                                                      ),
                                                      obscureText: _obscurePhonePassword,
                                                   ),
                                                   const SizedBox(height: 48),
                                                   SizedBox(
                                                     width: double.infinity,
                                                     child: ElevatedButton(
                                                       onPressed: _isLoading ? null : _showComingSoon,
                                                       child: const Text("Entrar"),
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
                        onPressed: () => context.go('/register'),
                        child: RichText(
                            text: TextSpan(
                                text: "¿No tienes cuenta? ",
                                style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                children: const [
                                    TextSpan(text: "Regístrate gratis", style: TextStyle(color: AppTheme.primaryBrand, fontWeight: FontWeight.bold))
                                ]
                            )
                        ),
                     ).animate().fade(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ),
          
          // PWA Install Prompt (Floating at the top right)
          const Positioned(
              top: 40,
              right: 16,
              left: 16,
              child: SafeArea(child: PwaInstallPrompt())
          ),
        ],
      ),
    );
  }
}
