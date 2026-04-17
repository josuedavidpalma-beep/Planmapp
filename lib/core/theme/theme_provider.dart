import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeNotifier() : super(ThemeMode.system) {
    _loadSync();
  }

  Future<void> _loadSync() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key);
    if (index != null) {
      state = ThemeMode.values[index];
    }
  }

  Future<void> toggle() async {
    final nextMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = nextMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, nextMode.index);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }
}
