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
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _processGuestFlow();
  }

  Future<void> _processGuestFlow() async {
    if (mounted) setState(() { _hasError = false; _errorMessage = null; _statusMessage = 'Alistando tu mesa...'; });
    try {
      // 1. Auth Anónima Orgánica (Silenciosa)
      if (_supabase.auth.currentSession == null) {
        await _supabase.auth.signInAnonymously();
      }
      
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) throw Exception("Fallo en generación de ID anónimo");

      if (widget.restaurantId == null) {
         if (mounted) {
             setState(() {
                 _hasError = true;
                 _errorMessage = "El código QR no es válido o está incompleto.";
             });
         }
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
        'creator_id': uid,
        'event_date': DateTime.now().toIso8601String(),
        'location_name': restaurantName,
        'status': 'active',
        'payment_mode': 'split',
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
      if (mounted) {
          setState(() {
              _hasError = true;
              if (e.toString().contains('Fetch') || e.toString().contains('ClientException')) {
                  _errorMessage = "Tu conexión a internet parece inestable. Por favor, asegúrate de tener buena señal y vuelve a intentarlo.";
              } else {
                  _errorMessage = "Hubo un problema procesando tu código QR. Por favor, intenta de nuevo.";
              }
          });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: _hasError 
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.orangeAccent, size: 64),
                        const SizedBox(height: 24),
                        const Text("Ups, algo falló", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Text(_errorMessage ?? "Error desconocido.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                            onPressed: _processGuestFlow,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Reintentar"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                                minimumSize: const Size(double.infinity, 54),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                            ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                            onPressed: () => context.go('/onboarding'),
                            child: const Text("Volver al Inicio", style: TextStyle(color: Colors.white54))
                        )
                    ],
                )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       const CircularProgressIndicator(color: Colors.greenAccent),
                       const SizedBox(height: 24),
                       Text(_statusMessage, style: const TextStyle(color: Colors.white, fontSize: 18))
                           .animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 800.ms),
                    ],
                )
        ),
      ),
    );
  }
}
