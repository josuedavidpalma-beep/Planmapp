import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      appBar: AppBar(title: const Text("Completa tu Perfil")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
                radius: 50, 
                backgroundColor: AppTheme.lightBackground, 
                child: Icon(Icons.person, size: 50, color: Colors.grey)
            ),
            const SizedBox(height: 8),
            const Text("Sube una foto (Próximamente)", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                  labelText: "¿Cómo te llamas?", 
                  border: OutlineInputBorder(),
                  helperText: "Para que tus amigos te reconozcan en los planes."
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
    );
  }
}
