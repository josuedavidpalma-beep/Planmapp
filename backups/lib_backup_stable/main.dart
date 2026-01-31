import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planmapp/core/router/app_router.dart';
import 'package:planmapp/core/theme/app_theme.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:planmapp/core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  Intl.defaultLocale = 'es_CO';
  
  runApp(
    const ProviderScope(
      child: PlanmappApp(),
    ),
  );
}

class PlanmappApp extends ConsumerWidget {
  const PlanmappApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Planmapp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
         GlobalMaterialLocalizations.delegate,
         GlobalWidgetsLocalizations.delegate,
         GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
         Locale('es', 'CO'), 
      ],
      routerConfig: router,
      builder: (context, child) {
        // RESPONSIVE WRAPPER FOR WEB
        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600), // Mobile View on Desktop
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
               boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)
               ] 
            ),
            child: child,
          ),
        );
      },
    );
  }
}
