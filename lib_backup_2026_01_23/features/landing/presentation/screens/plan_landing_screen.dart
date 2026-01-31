
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlanLandingScreen extends StatefulWidget {
  final String planId; // From route: /invite/:planId

  const PlanLandingScreen({super.key, required this.planId});

  @override
  State<PlanLandingScreen> createState() => _PlanLandingScreenState();
}

class _PlanLandingScreenState extends State<PlanLandingScreen> {
  Map<String, dynamic>? _planData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPlanData();
  }

  Future<void> _fetchPlanData() async {
    try {
      // Try to fetch plan details.
      // Note: This might fail if RLS policies require authentication and the user is not logged in.
      // In a production app, use an Edge Function with a service_role key to fetch public preview data safely.
      final res = await Supabase.instance.client
          .from('plans')
          .select('title, event_date, location_name')
          .eq('id', widget.planId)
          .maybeSingle();
      
      if (mounted) {
        setState(() {
           _planData = res;
           _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are on Web (Small vs Large screen)
    final isLargeScreen = MediaQuery.of(context).size.width > 800;
    
    final planTitle = _planData?['title'] ?? "Un Plan Genial";
    final planDate = _planData?['event_date'] != null 
        ? _planData!['event_date'].toString().split(' ').first // Simple format
        : "Fecha por definir";

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
           // Background Art
           Positioned.fill(
               child: Container(
                   decoration: BoxDecoration(
                       gradient: LinearGradient(
                           begin: Alignment.topLeft,
                           end: Alignment.bottomRight,
                           colors: [Colors.blue.shade50, Colors.purple.shade50],
                       )
                   ),
               )
           ),
           
           Center(
               child: _loading 
                  ? const CircularProgressIndicator()
                  : Container(
                   width: isLargeScreen ? 500 : double.infinity,
                   height: isLargeScreen ? 700 : double.infinity,
                   padding: const EdgeInsets.all(32),
                   decoration: isLargeScreen ? BoxDecoration(
                       color: Colors.white,
                       borderRadius: BorderRadius.circular(32),
                       boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0,10))]
                   ) : null,
                   child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                            // Logo
                            const Icon(Icons.map_rounded, size: 64, color: AppTheme.primaryBrand).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                            const SizedBox(height: 16),
                            Text("Planmapp", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                            const SizedBox(height: 48),

                            // Invitation Card
                            Text("¡Estás invitado!", style: TextStyle(color: AppTheme.secondaryBrand, fontWeight: FontWeight.bold, letterSpacing: 1.2)).animate().fadeIn().moveY(begin: 10),
                            const SizedBox(height: 16),
                            Text(planTitle, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center).animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 8),
                            Text("📅 $planDate", style: TextStyle(fontSize: 18, color: Colors.grey[600])).animate().fadeIn(delay: 300.ms),
                            const SizedBox(height: 32),
                            
                            // Authors / Members Mock (Still mock for now as fetching members is harder unauth)
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    _buildAvatar("https://i.pravatar.cc/150?u=1"),
                                    _buildAvatar("https://i.pravatar.cc/150?u=2"),
                                    const SizedBox(width: 8),
                                    const Text("+ amigos", style: TextStyle(fontWeight: FontWeight.bold))
                                ],
                            ).animate().fadeIn(delay: 400.ms),
                            
                            const Spacer(),
                            
                            // App Screenshot Mock or Blur
                            Container(
                                height: 150,
                                margin: const EdgeInsets.symmetric(vertical: 24),
                                decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade300)
                                ),
                                child: Center(
                                    child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                            const Icon(Icons.lock_outline, color: Colors.grey),
                                            const SizedBox(height: 8),
                                            Text("Descarga la App para ver el itinerario completo,\nvotar en encuestas y dividir gastos.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                        ],
                                    ),
                                ),
                            ),
                            
                            const Spacer(),
                            
                            // CTA
                            ElevatedButton(
                                onPressed: _launchAppStore,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryBrand,
                                    foregroundColor: Colors.white,
                                    fixedSize: const Size(double.infinity, 56),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 5
                                ),
                                child: const Text("🚀 Unirme al Plan (Abrir App)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ).animate().shimmer(delay: 1000.ms, duration: 1500.ms),
                            
                            const SizedBox(height: 16),
                            TextButton(
                                onPressed: () {
                                    // In Web: Go to Login to use web version
                                    context.go('/login');
                                },
                                child: const Text("Ya tengo cuenta, Iniciar Sesión Web"),
                            )
                       ],
                   ),
               )
           )
        ],
      ),
    );
  }

  Widget _buildAvatar(String url) {
      return Container(
          width: 40, height: 40,
          margin: const EdgeInsets.symmetric(horizontal: -6),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
          ),
      );
  }
  
  void _launchAppStore() async {
      // Try to launch deep link first
      final deepLink = Uri.parse("planmapp://plan/${widget.planId}");
      if (await canLaunchUrl(deepLink)) {
          await launchUrl(deepLink);
          return;
      }
      
      // Fallback to Store
      // In a real app, use logic to check Platform.isAndroid ? PlayStore : AppStore
      const storeUrl = "https://play.google.com/store/apps/details?id=com.planmapp"; 
      if (await canLaunchUrl(Uri.parse(storeUrl))) {
          await launchUrl(Uri.parse(storeUrl));
      } else {
          debugPrint("Could not launch store");
      }
  }
}
