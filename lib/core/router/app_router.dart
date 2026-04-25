import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:planmapp/core/theme/app_theme.dart';
import 'package:planmapp/core/providers/auth_provider.dart';
import 'package:planmapp/features/auth/presentation/screens/login_screen.dart';
import 'package:planmapp/features/auth/presentation/screens/register_screen.dart';
import 'package:planmapp/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:planmapp/features/auth/presentation/screens/update_password_screen.dart';
import 'package:planmapp/features/onboarding/presentation/screens/onboarding_setup_screen.dart';
import 'package:planmapp/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:planmapp/core/presentation/screens/main_wrapper_screen.dart';
import 'package:planmapp/features/dashboard/presentation/screens/dashboard_screen.dart'; // NEW
import 'package:planmapp/features/plans/presentation/screens/my_plans_screen.dart';

import 'package:planmapp/features/home/presentation/screens/home_screen.dart';
import 'package:planmapp/features/create_plan/presentation/screens/create_plan_screen.dart';
import 'package:planmapp/features/plan_detail/presentation/screens/plan_detail_screen.dart';
import 'package:planmapp/features/invite/presentation/screens/invite_screen.dart';
import 'package:planmapp/features/spots/presentation/screens/spots_screen.dart';
import 'package:planmapp/features/profile/presentation/screens/profile_screen.dart'; // Still needed for Drawer if accessed directly, but we will move it.
import 'package:planmapp/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/balances_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/debts_dashboard_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/guest_join_screen.dart';
import 'package:planmapp/features/expenses/presentation/screens/guest_split_screen.dart';
import 'package:planmapp/features/landing/presentation/screens/plan_landing_screen.dart'; // NEW landing
import 'package:planmapp/features/landing/presentation/screens/guest_scan_landing_screen.dart'; // B2B2C landing
import 'package:planmapp/features/admin/presentation/screens/super_admin_screen.dart';
import 'package:planmapp/features/social/presentation/screens/friends_screen.dart';
import 'package:planmapp/features/matchmaker/presentation/screens/ai_matchmaker_screen.dart';
import 'package:planmapp/features/chat/presentation/screens/peer_chat_redirector.dart' as planmapp_imports;

final rootNavigatorKey = GlobalKey<NavigatorState>(); // Key for root navigator
bool isRecoveringPasswordGlobal = false; // Add global state flag for auth callbacks

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
      // 1. Anti-404 Query Parameter Interceptor (GitHub Pages Fix & Push Notifications)
      if (state.uri.queryParameters.containsKey('nav')) {
          final nav = state.uri.queryParameters['nav'];
          if (nav == 'peer_chat' && state.uri.queryParameters.containsKey('peer_id')) {
              return '/peer_chat/${state.uri.queryParameters['peer_id']}';
          }
          return '/$nav';
      }
      if (state.uri.queryParameters.containsKey('invite')) {
          return '/invite/${state.uri.queryParameters['invite']}';
      }
      if (state.uri.queryParameters.containsKey('vaca')) {
          return '/vaca/${state.uri.queryParameters['vaca']}';
      }
      if (state.uri.queryParameters.containsKey('share_target')) {
          final title = state.uri.queryParameters['title'] ?? '';
          final text = state.uri.queryParameters['text'] ?? '';
          final url = state.uri.queryParameters['url'] ?? '';
          final combined = '$title $text $url'.trim();
          return '/create-plan?shared_text=${Uri.encodeComponent(combined)}';
      }

      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      
      final isLoggingIn = state.uri.path == '/login' || state.uri.path == '/register' || state.uri.path == '/forgot-password' || state.uri.path == '/onboarding';
    final isPublic = state.uri.path.startsWith('/join') || 
                     state.uri.path.startsWith('/scan') || 
                     state.uri.path.startsWith('/super-admin') || 
                     state.uri.path.startsWith('/invite') || 
                     state.uri.path.startsWith('/pago') || 
                     state.uri.path.startsWith('/vaca') || 
                     state.uri.queryParameters['guest'] == 'true' || 
                     state.uri.path == '/onboarding-setup';

      if (_isRecoveringPasswordGlobalCheck()) {
         if (state.uri.path != '/update-password') return '/update-password';
         return null;
      }

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
        path: '/scan',
        builder: (context, state) {
          final restaurantId = state.uri.queryParameters['rid'];
          return GuestScanLandingScreen(restaurantId: restaurantId);
        },
      ),
      GoRoute(
        path: '/super-admin',
        builder: (context, state) => const SuperAdminScreen(),
        redirect: (context, state) {
           final session = Supabase.instance.client.auth.currentSession;
           // Change this email to the actual master email as needed.
           if (session?.user.email?.toLowerCase() != 'josuedavidpalma@gmail.com') {
               return '/';
           }
           return null;
        }
      ),
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
        path: '/update-password',
        builder: (context, state) => const UpdatePasswordScreen(),
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
             path: '/spots',
             builder: (context, state) => const SpotsScreen(),
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
           final sharedText = state.uri.queryParameters['shared_text'];
           
           return CreatePlanScreen(
               initialTitle: extra?['initialTitle'] ?? sharedText,
               initialAddress: extra?['initialAddress'],
               initialDate: extra?['initialDate'],
               initialImageUrl: extra?['initialImageUrl'],
           );
        },
      ),
      GoRoute(
         path: '/plan/:id',
         parentNavigatorKey: rootNavigatorKey,
         builder: (context, state) {
            final tabParam = state.uri.queryParameters['tab'];
            final autoScanParam = state.uri.queryParameters['auto_scan'];
            return PlanDetailScreen(
               planId: state.pathParameters['id']!,
               initialTab: tabParam != null ? int.tryParse(tabParam) : null,
               autoScan: autoScanParam == 'true'
            );
         }
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
        builder: (context, state) => InviteScreen(planId: state.pathParameters['id']!),
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
        path: '/vaca/:id/wait',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
           final profileName = state.uri.queryParameters['name'] ?? 'Usuario';
           return Scaffold(
               appBar: AppBar(title: const Text("Tus partes seleccionadas")),
               body: Padding(
                   padding: const EdgeInsets.all(24.0),
                   child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                           const Icon(Icons.check_circle, size: 80, color: AppTheme.primaryBrand),
                           const SizedBox(height: 24),
                           Text("¡Todo listo, $profileName!", textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 8),
                           const Text("Tus selecciones han sido transmitidas al creador. Por favor, espera a que finalice el cierre de cuenta para recibir tu saldo final y las opciones de pago.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                           const SizedBox(height: 32),
                           ElevatedButton(
                               onPressed: () => context.go('/home'),
                               style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBrand, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
                               child: const Text("Volver al Inicio", style: TextStyle(fontWeight: FontWeight.bold)),
                           )
                       ]
                   )
               )
           );
        }
      ),
      GoRoute(
        path: '/debts',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
            final tabParam = state.uri.queryParameters['tab'];
            int initTab = 0;
            if (tabParam == 'payables') initTab = 1;
            return DebtsDashboardScreen(planId: null, initialTab: initTab);
        },
      ),
      GoRoute(
        path: '/pago/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => PlanLandingScreen(planId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/peer_chat/:peerId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
            // Late import to avoid circular dependencies if needed, or import at top
            return planmapp_imports.PeerChatRedirector(peerId: state.pathParameters['peerId']!);
        },
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
      GoRoute(
        path: '/ai-matchmaker',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AiMatchmakerScreen(),
      ),
    ],
  );
});

// Helper function
bool _isRecoveringPasswordGlobalCheck() => isRecoveringPasswordGlobal;

// Helper for Riverpod Stream to GoRouter RefreshListenable
class _StreamRouterRefresh extends ChangeNotifier {
  _StreamRouterRefresh(Stream<AuthState> stream) {
    notifyListeners();
    _subscription = stream.listen((authState) {
        if (authState.event == AuthChangeEvent.passwordRecovery) {
            isRecoveringPasswordGlobal = true;
        }
        notifyListeners();
    });
  }
  late final dynamic _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
