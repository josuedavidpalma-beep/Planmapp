import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/utils/pwa_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PwaInstallPrompt extends StatefulWidget {
  const PwaInstallPrompt({super.key});

  @override
  State<PwaInstallPrompt> createState() => _PwaInstallPromptState();
}

class _PwaInstallPromptState extends State<PwaInstallPrompt> with SingleTickerProviderStateMixin {
  bool _showPrompt = false;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _isIOS = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _checkInstallStatus();
  }

  Future<void> _checkInstallStatus() async {
    // Only target Web
    if (!kIsWeb) return;

    final isIos = defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    
    // Only show for mobile web
    if (!isIos && !isAndroid) return;

    if (mounted) {
       setState(() {
         _isIOS = isIos;
       });
    }

    // Check if the user already installed the PWA
    if (isPwaInstalled()) return;

    // Check if the user has dismissed the prompt before
    final prefs = await SharedPreferences.getInstance();
    final hasDismissed = prefs.getBool('dismissed_pwa_prompt') ?? false;
    if (hasDismissed) return;

    // Show the prompt
    if (mounted) {
      setState(() => _showPrompt = true);
      _controller.forward();
    }
  }

  void _dismissPrompt() async {
    await _controller.reverse();
    setState(() => _showPrompt = false);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dismissed_pwa_prompt', true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPrompt) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryBrand.withOpacity(0.5)),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppTheme.primaryBrand.withOpacity(0.2), shape: BoxShape.circle),
                    child: Icon(_isIOS ? Icons.apple : Icons.android, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isIOS ? "¡Instala Planmapp para Notificaciones!" : "¡Descarga la App de Planmapp!",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                GestureDetector(
                  onTap: _dismissPrompt,
                  child: const Icon(Icons.close, color: Colors.white54, size: 20),
                )
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _isIOS 
                ? "Para recibir avisos de tus cuenta y planes sin retrasos, debes instalar la app en tu iPhone."
                : "Usa Planmapp como app nativa para obtener la mejor velocidad y alertas en tu celular.",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(_isIOS ? Icons.ios_share : Icons.more_vert, color: Colors.blueAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                        child: RichText(
                            text: TextSpan(
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                children: _isIOS 
                                ? const [
                                    TextSpan(text: "Toca el ícono "),
                                    TextSpan(text: "Compartir", style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: " en Safári y luego selecciona "),
                                    TextSpan(text: "Añadir a la pantalla de inicio", style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: "."),
                                  ]
                                : const [
                                    TextSpan(text: "Toca el ícono de "),
                                    TextSpan(text: "Menú (⋮)", style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: " arriba en Chrome y selecciona "),
                                    TextSpan(text: "Instalar aplicación", style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: " o Añadir a inicio."),
                                  ]
                            )
                        )
                    )
                  ],
                ),
            )
          ],
        ),
      ),
    );
  }
}
