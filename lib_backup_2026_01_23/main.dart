import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planmapp/core/router/app_router.dart';
import 'package:planmapp/core/theme/theme_provider.dart';
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
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Planmapp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
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
        // GLOBAL ERROR WIDGET (Replaces Red Screen)
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Material(
            color: AppTheme.primaryBrand,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sentiment_dissatisfied_rounded, size: 64, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      "Algo salió mal...",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    Text(
                      "Error técnico: ${details.exception}", // SHOW THE ERROR
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Estamos trabajando para arreglarlo.",
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                         onPressed: () {}, // Just a placebo for now, or could try to navigation pop
                         style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.primaryBrand),
                         child: const Text("Intentar de nuevo"),
                    )
                  ],
                ),
              ),
            ),
          );
        };

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
