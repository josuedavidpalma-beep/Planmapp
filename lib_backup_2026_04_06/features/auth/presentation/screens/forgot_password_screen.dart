import 'package:flutter/material.dart';
import 'package:planmapp/core/services/auth_service.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _reset() async {
    if (_emailController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await AuthService().resetPasswordForEmail(_emailController.text.trim());
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Si el correo existe, recibirás un enlace de recuperación."))
         );
         Navigator.pop(context); // Go back to Login
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recuperar Contraseña")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text("Ingresa tu correo para recibir un enlace de recuperación."),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Correo Electrónico", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _reset,
                style: ElevatedButton.styleFrom(
                   padding: const EdgeInsets.all(16),
                   backgroundColor: AppTheme.primaryBrand,
                   foregroundColor: Colors.white
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Enviar Enlace"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
