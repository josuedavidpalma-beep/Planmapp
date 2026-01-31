import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:planmapp/features/home/presentation/widgets/spontaneous_plan_sheet.dart'; // NEW

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
    if (location.startsWith('/social')) return 3; // Index 2 is the FAB
    if (location.startsWith('/profile')) return 4;
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
      case 3:
        context.go('/social');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);

    // If we are in a sub-route that shouldn't show the nav bar (like plan detail), 
    // we might want to hide it, but ShellRoute usually keeps it. 
    // For now, consistent persistence.

    return Scaffold(
      body: widget.child,
      floatingActionButton: FloatingActionButton(
          tooltip: 'Crear Nuevo Plan',
          elevation: 4,
          backgroundColor: AppTheme.primaryBrand,
          shape: const CircleBorder(),
          onPressed: () => _showPlanCreationSheet(context),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 28, color: Colors.white),
              Text("PLAN IT", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Theme.of(context).cardColor,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Left Side
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
                label: "Mis Planes", 
                isSelected: currentIndex == 1,
                onTap: () => _onItemTapped(1, context),
              ),
              
              const SizedBox(width: 48), // Gap for FAB

              // Right Side
              _NavBarItem(
                icon: Icons.account_balance_wallet_outlined, 
                activeIcon: Icons.account_balance_wallet_rounded,
                label: "Finanzas", // WAS Social
                isSelected: currentIndex == 3,
                onTap: () => _onItemTapped(3, context),
              ),
              _NavBarItem(
                icon: Icons.person_outline_rounded, 
                activeIcon: Icons.person_rounded,
                label: "Perfil", 
                isSelected: currentIndex == 4,
                onTap: () => _onItemTapped(4, context),
              ),
            ],
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
                      const SizedBox(height: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color, size: 24),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
