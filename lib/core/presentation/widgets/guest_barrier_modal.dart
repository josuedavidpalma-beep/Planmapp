import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';

class GuestBarrierModal {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: AppTheme.cardDark,
      builder: (c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.cloud_upload_rounded, size: 60, color: AppTheme.primaryBrand),
            const SizedBox(height: 20),
            const Text(
              "¡Guarda esta cuenta y cobra fácil!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Para usar el cobro automático con notificaciones push y guardar este recibo en la nube, crea tu cuenta en 30 segundos. Nosotros nos encargamos de avisarle a tus amigos.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(c);
                // Evitamos un push sencillo, mejor forzar el registro y luego redirigir 
                // De momento los mandamos a registro
                context.push('/register?upgrade=true');
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBrand,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Registrarme Gratis", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Solo mirar, gracias", style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }
}
