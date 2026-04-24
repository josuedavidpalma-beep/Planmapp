import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';

class GuestScanLandingScreen extends StatefulWidget {
  final String? restaurantId;
  const GuestScanLandingScreen({super.key, required this.restaurantId});

  @override
  State<GuestScanLandingScreen> createState() => _GuestScanLandingScreenState();
}

class _GuestScanLandingScreenState extends State<GuestScanLandingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _statusMessage = 'Alistando tu mesa...';

  @override
  void initState() {
    super.initState();
    _processGuestFlow();
  }

  Future<void> _processGuestFlow() async {
    try {
      // 1. Auth AnAcónima Orgánica (Silenciosa)
      if (_supabase.auth.currentSession == null) {
        await _supabase.auth.signInAnonymously();
      }
      
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) throw Exception("Fallo en generación de ID anónimo");

      if (widget.restaurantId == null) {
         context.go('/onboarding');
         return;
      }

      // 2. Traer info del Restaurante
      setState(() => _statusMessage = 'Preparando cuenta...');
      final restRes = await _supabase.from('restaurants').select('name').eq('id', widget.restaurantId as Object).maybeSingle();
      
      // Manejar si el restaurante no existe (para pruebas)
      final restaurantName = restRes != null ? restRes['name'] : 'Mesa Rápida';

      // 3. Crear Plan Temporal (Sobrescribiendo Planmapp nativo)
      final planRes = await _supabase.from('plans').insert({
        'title': 'Ticket en $restaurantName',
        'theme': 'Gastronómico',
        'creator_id': uid,
        'date': DateTime.now().toIso8601String(),
        'time': '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        'location': restaurantName,
        'is_temporal': true,
        'restaurant_id': widget.restaurantId
      }).select('id').single();

      final planId = planRes['id'];

      // Redirigir al Plan, enviándolo directamente a la vista del Ticket Scanner o Presupuesto
      if (mounted) {
        // En base a la estructura de tabs (tab=2 suele ser presupuesto y tab=1 recibos)
        context.go('/plan/$planId?tab=2&auto_scan=true'); 
      }

    } catch (e) {
      debugPrint("Error en flujo de invitado: $e");
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             const CircularProgressIndicator(color: Colors.greenAccent),
             const SizedBox(height: 24),
             Text(_statusMessage, style: const TextStyle(color: Colors.white, fontSize: 18))
                 .animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 800.ms),
          ],
        ),
      ),
    );
  }
}
