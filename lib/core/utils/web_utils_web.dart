// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool get isPwaStandalone {
  return html.window.matchMedia('(display-mode: standalone)').matches;
}
