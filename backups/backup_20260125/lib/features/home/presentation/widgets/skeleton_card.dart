
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(width: 60, height: 60, color: Colors.grey[300]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(width: 120, height: 16, color: Colors.grey[300]),
                   const SizedBox(height: 8),
                   Container(width: 80, height: 12, color: Colors.grey[300]),
                ],
              ),
            )
          ],
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.grey[100]);
  }
}
