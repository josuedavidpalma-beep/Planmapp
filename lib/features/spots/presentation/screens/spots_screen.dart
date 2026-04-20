import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class SpotsScreen extends StatefulWidget {
  const SpotsScreen({super.key});

  @override
  State<SpotsScreen> createState() => _SpotsScreenState();
}

class _SpotsScreenState extends State<SpotsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text("Planmapp Spots", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.handyman_rounded, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text("¡Planmapp Spots!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
              child: const Text("🚧 En Construcción / Próximamente", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.0),
              child: Text("Muy pronto aquí encontrarás un feed inmersivo para descubrir los mejores eventos y locales de la ciudad.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            )
          ],
        ),
      ),
    );
  }
}
