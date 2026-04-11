import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GuestJoinScreen extends StatefulWidget {
  final String expenseId;
  const GuestJoinScreen({super.key, required this.expenseId});

  @override
  State<GuestJoinScreen> createState() => _GuestJoinScreenState();
}

class _GuestJoinScreenState extends State<GuestJoinScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = true;
  String _expenseTitle = "esta vaca";
  
  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  Future<void> _checkAuthAndLoad() async {
      try {
          final res = await Supabase.instance.client.from('expenses').select('title').eq('id', widget.expenseId).single();
          if (mounted) setState(() => _expenseTitle = res['title']);
          
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
              // Pre-fill or skip directly if authenticated
              final profile = await Supabase.instance.client.from('profiles').select('full_name').eq('id', user.id).single();
              final name = profile['full_name'] as String;
              if (mounted) {
                 context.go('/vaca/${widget.expenseId}/split?name=${Uri.encodeComponent(name)}&uid=${user.id}');
              }
          } else {
             if (mounted) setState(() => _isLoading = false);
          }
      } catch (e) {
         if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando la vaca: $e')));
         }
      }
  }

  void _join() {
      if (_nameController.text.trim().isEmpty) return;
      final guestName = "guest_${_nameController.text.trim()}"; 
      context.go('/vaca/${widget.expenseId}/split?name=${Uri.encodeComponent(_nameController.text.trim())}&uid=$guestName');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    return Scaffold(
        appBar: AppBar(title: const Text("Unirse a la Vaca", style: TextStyle(fontWeight: FontWeight.bold))),
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
                            Text("Te han invitado a dividir\n*$_expenseTitle*", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text("Ingresa tu nombre para comenzar y seleccionar qué consumiste.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
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
                                child: const Text("Entrar a la Vaca", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            )
                        ]
                    )
                )
            )
        )
    );
  }
}
