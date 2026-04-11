import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/presentation/widgets/bouncy_button.dart';

class DancingEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;

  const DancingEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                  color: AppTheme.primaryBrand.withOpacity(0.1),
                  shape: BoxShape.circle,
               ),
               child: Icon(icon, size: 72, color: AppTheme.primaryBrand.withOpacity(0.8)),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2000.ms, curve: Curves.easeInOut)
            .then()
            .shake(hz: 4, curve: Curves.easeInOut), // Subtle wiggle
            
            const SizedBox(height: 32),
            
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ).animate().fade(duration: 500.ms).slideY(begin: 0.2, end: 0),
            
            const SizedBox(height: 12),
            
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
            ).animate().fade(delay: 200.ms, duration: 500.ms),
            
            const SizedBox(height: 40),
            
            if (buttonLabel != null && onButtonPressed != null)
              BouncyButton(
                onPressed: onButtonPressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                     color: AppTheme.primaryBrand,
                     borderRadius: BorderRadius.circular(30),
                     boxShadow: [
                        BoxShadow(color: AppTheme.primaryBrand.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))
                     ]
                  ),
                  child: Text(buttonLabel!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ).animate().fade(delay: 400.ms).scale(),
          ],
        ),
      ),
    );
  }
}
