// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool isPwaInstalled() {
  try {
    // Standard CSS media query for standalone mode
    final matchesStandalone = html.window.matchMedia('(display-mode: standalone)').matches;
    
    // Fallback specific to iOS Safari
    final isIosStandalone = (html.window.navigator as dynamic).standalone == true;

    return matchesStandalone || isIosStandalone;
  } catch (e) {
    return false;
  }
}
