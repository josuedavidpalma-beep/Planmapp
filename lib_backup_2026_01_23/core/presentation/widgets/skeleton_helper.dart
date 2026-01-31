import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonHelper {
  static Widget rectangular({
    double width = double.infinity,
    double height = 16.0,
    double borderRadius = 8.0,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  static Widget circular({
    double radius = 24.0,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  static Widget planCardSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                rectangular(width: 60, height: 20, borderRadius: 12),
                const Spacer(),
                circular(radius: 12),
              ],
            ),
            const SizedBox(height: 16),
            // Title - Use fraction of width instead of fixed pixel
            LayoutBuilder(builder: (context, c) => rectangular(width: c.maxWidth * 0.7, height: 24)), 
            const SizedBox(height: 8),
            Row(
              children: [
                rectangular(width: 80, height: 16),
                const SizedBox(width: 12),
                Expanded(child: rectangular(height: 16)), // Use Expanded to fill remaining space accurately
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Avatar Stack effect using widthFactor instead of negative padding
                Align(widthFactor: 0.7, child: circular(radius: 14)),
                Align(widthFactor: 0.7, child: circular(radius: 14)),
                Align(widthFactor: 0.7, child: circular(radius: 14)),
                const SizedBox(width: 16), // Extra space after stack
                const Spacer(),
                rectangular(width: 50, height: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
