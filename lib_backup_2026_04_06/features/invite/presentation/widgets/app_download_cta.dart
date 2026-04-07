import 'package:flutter/material.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDownloadCTA extends StatelessWidget {
  const AppDownloadCTA({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryBrand.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text(
            "¡Genial! Ya estás en la lista. 🎉",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBrand),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Para chatear, votar y ver la ubicación exacta, descarga PlanMapp.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _StoreButton(
                icon: Icons.android,
                label: "Google Play",
                onTap: () {
                   // launchUrl(Uri.parse("market://details?id=io.planmapp.app")); 
                },
              ),
              _StoreButton(
                icon: Icons.apple,
                label: "App Store",
                onTap: () {
                   // launchUrl(Uri.parse("https://apps.apple.com/..."));
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
               // Try to open deep link directly
               final Uri deepLink = Uri.parse("io.planmapp.app://home");
               if (await canLaunchUrl(deepLink)) {
                 await launchUrl(deepLink);
               }
            },
            child: const Text("Ya tengo la app (Abrir)"),
          )
        ],
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StoreButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }
}
