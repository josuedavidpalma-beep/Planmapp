import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:planmapp/core/providers/auth_provider.dart';
import 'package:planmapp/features/auth/presentation/screens/login_screen.dart';
import 'package:planmapp/features/auth/presentation/screens/register_screen.dart';
import 'package:planmapp/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:planmapp/features/onboarding/presentation/screens/onboarding_setup_screen.dart';
import 'package:planmapp/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:planmapp/core/presentation/screens/main_wrapper_screen.dart';
import 'package:planmapp/features/dashboard/presentation/screens/dashboard_screen.dart'; // NEW
import 'package:planmapp/features/plans/presentation/screens/my_plans_screen.dart';

import 'package:planmapp/features/home/presentation/screens/home_screen.dart';
import 'package:planmapp/features/create_plan/presentation/screens/create_plan_screen.dart';
import 'package:planmapp/features/plan_detail/presentation/screens/plan_detail_screen.dart';
import 'package:planmapp/features/invite/presentation/screens/invite_screen.dart';
import 'package:planmapp/features/profile/presentation/screens/profile_screen.dart';
import 'package:planmapp/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/balances_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/guest_join_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/guest_split_screen.dart';
import 'package:planmapp/features/landing/presentation/screens/plan_landing_screen.dart'; // NEW landing
import 'package:planmapp/features/social/presentation/screens/friends_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(); // Key for root navigator

final appRouterProvider = Provider<GoRouter>((ref) {
  // Do NOT watch authProvider here to avoid rebuilding GoRouter on every auth change.
  // Instead, rely on refreshListenable to trigger redirects.
  
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    refreshListenable: _StreamRouterRefresh(Supabase.instance.client.auth.onAuthStateChange),
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      
      final isLoggingIn = state.uri.path == '/login' || state.uri.path == '/register' || state.uri.path == '/forgot-password' || state.uri.path == '/onboarding';
    // 1. PUBLIC CHECK UPDATE
    final isPublic = state.uri.path.startsWith('/join') || 
                     state.uri.path.startsWith('/invite') || 
                     state.uri.path.startsWith('/pago') || 
                     state.uri.path.startsWith('/vaca') || 
                     state.uri.path == '/onboarding-setup';

      if (!isLoggedIn && !isLoggingIn && !isPublic) {
        return '/onboarding'; // Default landing for guests
      }

      final isAnonymous = session?.user.isAnonymous ?? false;

      if (isLoggedIn && isLoggingIn) {
        // Allow the register screen to manually navigate to onboarding-setup on success
        if (state.uri.path == '/register') return null;
        
        // If the user is anonymous, allow them to view auth screens to upgrade their account
        if (isAnonymous) return null;

        return '/'; // Already logged in
      }

      // If logged in but no nickname → send to onboarding-setup (first time)
      // BUT: anonymous/guest users skip this - they don't need a profile

      if (isLoggedIn && !isAnonymous && !isPublic && state.uri.path != '/onboarding-setup') {
        try {
          final uid = session.user.id;
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('nickname')
              .eq('id', uid)
              .maybeSingle();
          final hasNickname = profile != null && (profile['nickname'] as String?)?.isNotEmpty == true;
          if (!hasNickname) return '/onboarding-setup';
        } catch (_) {}
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/onboarding-setup',
        builder: (context, state) => const OnboardingSetupScreen(),
      ),
      
      // SHELL ROUTE for Persistent Bottom Nav
      ShellRoute(
        builder: (context, state, child) {
           return MainWrapperScreen(key: state.pageKey, location: state.uri.toString(), child: child);
        },
        routes: [
           GoRoute(
             path: '/home',
             builder: (context, state) => const HomeScreen(),
           ),
           GoRoute(
             path: '/plans',
             builder: (context, state) => const MyPlansScreen(),
           ),
           GoRoute(
             path: '/social',
             builder: (context, state) => const DashboardScreen(),
           ),
           GoRoute(
             path: '/profile',
             builder: (context, state) => const ProfileScreen(),
           ),
        ],
      ),

      // Redirect root to home
      GoRoute(
        path: '/',
        redirect: (_, __) => '/home',
      ),

      // Fullscreen Routes (Overlaying the Shell)
      GoRoute(
        path: '/create-plan',
        parentNavigatorKey: rootNavigatorKey, 
        builder: (context, state) {
           final extra = state.extra as Map<String, dynamic>?;
           return CreatePlanScreen(
               initialTitle: extra?['initialTitle'],
               initialAddress: extra?['initialAddress'],
               initialDate: extra?['initialDate'],
               initialImageUrl: extra?['initialImageUrl'],
           );
        },
      ),
      GoRoute(
         path: '/plan/:id',
         parentNavigatorKey: rootNavigatorKey,
         builder: (context, state) => PlanDetailScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
         path: '/plan/:id/balances',
         parentNavigatorKey: rootNavigatorKey,
         builder: (context, state) => BalancesScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/join/:id', 
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => InviteScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/invite/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => PlanLandingScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vaca/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => GuestJoinScreen(expenseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/vaca/:id/split',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
           final Uri uri = state.uri;
           return GuestSplitScreen(
               expenseId: state.pathParameters['id']!,
               guestName: uri.queryParameters['name'] ?? 'Invitado',
               guestUid: uri.queryParameters['uid'] ?? 'guest_anon',
           );
        }
      ),
      GoRoute(
        path: '/pago/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => PlanLandingScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/friends',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FriendsScreen(),
      ),
    ],
  );
});

// Helper for Riverpod Stream to GoRouter RefreshListenable
class _StreamRouterRefresh extends ChangeNotifier {
  _StreamRouterRefresh(Stream stream) {
    notifyListeners();
    _subscription = stream.listen((_) => notifyListeners());
  }
  late final dynamic _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
