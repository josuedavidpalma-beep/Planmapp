import 'package:flutter/material.dart';
import 'package:planmapp/features/profile/presentation/screens/profile_screen.dart';

class ProfileDrawer extends StatelessWidget {
  const ProfileDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      // ProfileScreen returns a Scaffold which perfectly fills the drawer and gives it an AppBar 
      child: const ProfileScreen(),
    );
  }
}
