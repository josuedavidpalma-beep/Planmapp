import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/router/app_router.dart'; // import to access global bool

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  Future<void> _updatePassword() async {
    final pwd = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pwd.length < 6) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("La contraseña de tener mínimo 6 caracteres.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
        return;
    }
    if (pwd != confirm) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Las contraseñas no coinciden.", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
        return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: pwd));
      
      // Reset recovery state lock
      isRecoveringPasswordGlobal = false;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Contraseña actualizada con éxito!")));
        context.go('/home');
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

          // 3. CONTENT
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   // LOGO / BRANDING
                   const Icon(Icons.password_rounded, size: 64, color: AppTheme.primaryBrand)
                        .animate().fade().scale(),
                   const SizedBox(height: 16),
                   Text(
                     "Nueva Contraseña", 
                     style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)
                   ).animate().fade().slideY(begin: 0.2, end: 0),
                   const SizedBox(height: 8),
                   Text(
                     "Establece una nueva clave para tu cuenta.", 
                     style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                     textAlign: TextAlign.center,
                   ).animate().fade(delay: 100.ms),
                   
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
                                          controller: _passwordController,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                              labelText: "Nueva Contraseña", 
                                              prefixIcon: const Icon(Icons.lock_outline),
                                              suffixIcon: IconButton(
                                                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                              )
                                          ),
                                          obscureText: _obscurePassword,
                                       ),
                                       const SizedBox(height: 16),
                                       TextField(
                                          controller: _confirmController,
                                          style: const TextStyle(color: Colors.white),
                                          decoration: InputDecoration(
                                              labelText: "Confirmar Contraseña", 
                                              prefixIcon: const Icon(Icons.lock_reset),
                                              suffixIcon: IconButton(
                                                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                              )
                                          ),
                                          obscureText: _obscureConfirm,
                                       ),
                                       const SizedBox(height: 32),
                                       SizedBox(
                                         width: double.infinity,
                                         child: ElevatedButton(
                                           onPressed: _isLoading ? null : _updatePassword,
                                           child: _isLoading 
                                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                                              : const Text("Guardar Contraseña"),
                                         ),
                                       ),
                                   ],
                               ),
                           ),
                       ),
                   ).animate().fade(delay: 300.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
