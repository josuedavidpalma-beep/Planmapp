import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestJoinScreen extends StatefulWidget {
  final String planId;
  const GuestJoinScreen({super.key, required this.planId});

  @override
  State<GuestJoinScreen> createState() => _GuestJoinScreenState();
}

class _GuestJoinScreenState extends State<GuestJoinScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = true;
  String _planTitle = "la cuenta";
  
  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
      try {
          final res = await Supabase.instance.client.from('plans').select('title').eq('id', widget.planId).maybeSingle();
          if (res != null && mounted) {
              setState(() => _planTitle = res['title'] ?? "la cuenta");
          }
          
          final user = Supabase.instance.client.auth.currentUser;
          // If the user already has a nickname/profile, just log them straight to the plan
          if (user != null) {
              final profile = await Supabase.instance.client.from('profiles').select('full_name, nickname').eq('id', user.id).maybeSingle();
              if (profile != null && (profile['nickname'] != null || profile['full_name'] != null)) {
                  if (mounted) {
                     context.go('/plan/${widget.planId}?tab=2');
                     return;
                  }
              }
          }
          
          if (mounted) setState(() => _isLoading = false);
      } catch (e) {
         if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando el grupo: $e')));
         }
      }
  }

  Future<void> _join() async {
      if (_nameController.text.trim().isEmpty) return;
      
      setState(() => _isLoading = true);
      
      try {
          final name = _nameController.text.trim();
          var user = Supabase.instance.client.auth.currentUser;
          
              // Generate anonymous session if they aren't logged in at all!
          if (user == null) {
              final res = await Supabase.instance.client.auth.signInAnonymously();
              user = res.user;
              // Ensure profile is immediately upserted instead of waiting for DB trigger which might set 'Nuevo Usuario'
              if (user != null) {
                  await Supabase.instance.client.from('profiles').upsert({
                      'id': user.id,
                      'full_name': name,
                      'nickname': name,
                      'updated_at': DateTime.now().toIso8601String()
                  });
              }
          }
          
          if (user != null) {
              // Also update if they were already logged in but had no name
              await Supabase.instance.client.from('profiles').update({
                  'full_name': name,
                  'nickname': name
              }).eq('id', user.id);
              
              // Register them formally as plan members so they can split!
              await Supabase.instance.client.from('plan_members').upsert({
                  'plan_id': widget.planId,
                  'user_id': user.id,
                  'status': 'accepted',
                  'role': 'member'
              }, onConflict: 'plan_id, user_id');
              
              if (mounted) {
                 context.go('/plan/${widget.planId}?tab=2');
              }
          }
      } catch (e) {
          if (mounted) {
              setState(() => _isLoading = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al ingresar: $e')));
          }
      }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    return Scaffold(
        appBar: AppBar(title: const Text("Unirse", style: TextStyle(fontWeight: FontWeight.bold))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            const Icon(Icons.receipt_long, size: 80, color: AppTheme.primaryBrand),
                            const SizedBox(height: 24),
                            Text("Te han invitado a dividir\n*$_planTitle*", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text("Ingresa tu nombre para entrar y ver la cuenta.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 32),
                            TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                    labelText: "¿Cómo te llamas?",
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.person),
                                ),
                                onSubmitted: (_) => _join(),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                                onPressed: _join,
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                                child: const Text("Entrar a la Cuenta", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            )
                        ]
                    )
                )
            )
        )
    );
  }
}
