import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planmapp/features/onboarding/presentation/screens/welcome_screen.dart';

import 'package:planmapp/features/home/presentation/screens/home_screen.dart';
import 'package:planmapp/features/create_plan/presentation/screens/create_plan_screen.dart';
import 'package:planmapp/features/plan_detail/presentation/screens/plan_detail_screen.dart';
import 'package:planmapp/features/invite/presentation/screens/invite_screen.dart';
import 'package:planmapp/features/profile/presentation/screens/profile_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/create-plan',
        builder: (context, state) => const CreatePlanScreen(),
      ),
      GoRoute(
        path: '/plan/:id',
        builder: (context, state) => PlanDetailScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invite/:id',
        builder: (context, state) => InviteScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
