import 'package:flutter/material.dart';

class SkeletonCard extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 200,
    this.width = double.infinity,
    this.borderRadius = 24,
  });

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.2, end: 0.6).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 20),
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              color: Colors.grey[700], // Middle grey that scales well in both dark and light
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  final double height;
  
  const SkeletonList({super.key, this.count = 3, this.height = 200});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (index) => SkeletonCard(height: height)),
    );
  }
}
