import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/features/games/presentation/screens/roulette_screen.dart';

class GamesHubScreen extends StatelessWidget {
  final String planId; // Needed to fetch participants
  const GamesHubScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("¿Quién Paga? 🎲", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "¡Que la suerte decida!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              "Elige un juego para sortear gastos o simplemente divertirte con tu grupo.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                   _buildGameCard(
                    context, 
                    "La Ruleta", 
                    "assets/icons/roulette.svg", // Placeholder icon path
                    Colors.purpleAccent,
                    Icons.casino_rounded,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => RouletteScreen(planId: planId))),
                  ),
                   _buildGameCard(
                    context, 
                    "Dedos del Destino", 
                    "assets/icons/finger.svg", 
                    Colors.blueAccent,
                    Icons.fingerprint_rounded,
                    () => _showComingSoon(context),
                  ),
                   _buildGameCard(
                    context, 
                    "Patata Caliente", 
                    "assets/icons/bomb.svg", 
                    Colors.redAccent,
                    Icons.timer_rounded,
                    () => _showComingSoon(context),
                  ),
                   _buildGameCard(
                    context, 
                    "Naipe Traicionero", 
                    "assets/icons/cards.svg", 
                    Colors.orangeAccent,
                    Icons.style_rounded,
                    () => _showComingSoon(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, String title, String iconPath, Color color, IconData fallbackIcon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
                ]
              ),
              child: Icon(fallbackIcon, size: 32, color: color), 
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color.withOpacity(0.9)),
            )
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("¡Próximamente! Estamos puliendo este juego. 🛠️"), backgroundColor: Colors.grey[800], behavior: SnackBarBehavior.floating,)
    );
  }
}
