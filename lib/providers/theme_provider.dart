import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeProvider({SharedPreferences? prefs}) : _prefs = prefs {
    _loadTheme();
  }

  void _loadTheme() {
    if (_prefs != null) {
      final isDark = _prefs.getBool('is_dark_theme') ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    }
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _prefs?.setBool('is_dark_theme', isDark);
    notifyListeners();
  }
}
