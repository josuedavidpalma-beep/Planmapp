import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:planmapp/features/home/presentation/widgets/spontaneous_plan_sheet.dart'; 
import 'package:planmapp/core/presentation/widgets/guest_barrier.dart';

class MainWrapperScreen extends StatefulWidget {
  final Widget child;
  final String location;

  const MainWrapperScreen({super.key, required this.child, required this.location});

  @override
  State<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends State<MainWrapperScreen> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = widget.location;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/plans')) return 1;
    if (location.startsWith('/social')) return 2;
    if (location.startsWith('/spots')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/plans');
        break;
      case 2:
        context.go('/social');
        break;
      case 3:
        context.go('/spots');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      extendBody: true, 
      body: widget.child,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ]
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                height: 64,
                color: Theme.of(context).cardColor.withOpacity(0.7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavBarItem(
                icon: Icons.explore_outlined, 
                activeIcon: Icons.explore_rounded,
                label: "Explorar", 
                isSelected: currentIndex == 0,
                onTap: () => _onItemTapped(0, context),
              ),
              _NavBarItem(
                icon: Icons.calendar_today_outlined, 
                activeIcon: Icons.calendar_today_rounded,
                label: "Planes", 
                isSelected: currentIndex == 1,
                onTap: () => _onItemTapped(1, context),
              ),
              
              // Central Floating Button
              GestureDetector(
                onTap: () => GuestBarrier.protect(context, () => _showPlanCreationSheet(context)),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryBrand, 
                    shape: BoxShape.circle,
                    boxShadow: [
                       BoxShadow(color: AppTheme.primaryBrand, blurRadius: 10, offset: Offset(0, 4))
                    ]
                  ),
                  child: const Center(child: Icon(Icons.add_rounded, color: Colors.white, size: 28)),
                )
              ),

              _NavBarItem(
                icon: Icons.handyman_outlined, 
                activeIcon: Icons.handyman_rounded,
                label: "Herram.", 
                isSelected: currentIndex == 2,
                onTap: () => _onItemTapped(2, context),
              ),
              _NavBarItem(
                icon: Icons.slow_motion_video_outlined, 
                activeIcon: Icons.slow_motion_video_rounded,
                label: "Spots", 
                isSelected: currentIndex == 3,
                onTap: () => _onItemTapped(3, context),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _showPlanCreationSheet(BuildContext context) {
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 24),
                      const Text("Crear un Plan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      _buildPlanOption(
                          context,
                          icon: Icons.calendar_month_rounded,
                          color: AppTheme.primaryBrand,
                          title: "Plan Organizado",
                          subtitle: "Pon fecha, encuesta y organiza con calma.",
                          onTap: () {
                              Navigator.pop(context);
                              context.push('/create-plan');
                          }
                      ),
                      const SizedBox(height: 12),
                      _buildPlanOption(
                          context,
                          icon: Icons.flash_on_rounded,
                          color: Colors.orange,
                          title: "Plan Espontáneo",
                          subtitle: "¡Ya, ahora! Geolocalización y lugares abiertos.",
                          onTap: () {
                              Navigator.pop(context); // Close selection sheet
                              // Open Spontaneous Sheet
                              showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (c) => const SpontaneousPlanSheet()
                              );
                          }
                      ),
                      const SizedBox(height: 24),
                  ],
              ),
          )
      );
  }

  Widget _buildPlanOption(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
      return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                  children: [
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(icon, color: color),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                          )
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
              ),
          ),
      );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.primaryBrand : Colors.grey;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
