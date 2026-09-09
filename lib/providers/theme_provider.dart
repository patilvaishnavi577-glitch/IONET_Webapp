import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences? _prefs;
  ThemeMode _themeMode = ThemeMode.dark;
  String _fontSize = 'Medium'; // Small (0.8), Medium (1.0 default), Large (1.2)

  ThemeProvider({SharedPreferences? prefs}) : _prefs = prefs {
    _loadTheme();
  }

  void _loadTheme() {
    if (_prefs != null) {
      final modeStr = _prefs.getString('theme_mode');
      if (modeStr != null) {
        if (modeStr == 'light') {
          _themeMode = ThemeMode.light;
        } else if (modeStr == 'dark') {
          _themeMode = ThemeMode.dark;
        } else {
          _themeMode = ThemeMode.system;
        }
      } else {
        // Fallback for legacy boolean
        final isDark = _prefs.getBool('is_dark_theme');
        if (isDark != null) {
          _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
        } else {
          _themeMode = ThemeMode.dark;
        }
      }

      final savedFontSize = _prefs.getString('font_size');
      if (savedFontSize != null) {
        _fontSize = savedFontSize;
      }
    }
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  String get fontSize => _fontSize;

  double get fontScaleFactor {
    switch (_fontSize) {
      case 'Small':
        return 0.8;
      case 'Large':
        return 1.2;
      case 'Medium':
      default:
        return 1.0;
    }
  }

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  String get fontSizeName {
    switch (_fontSize) {
      case 'Small':
        return 'Small';
      case 'Large':
        return 'Large';
      case 'Medium':
      default:
        return 'Medium';
    }
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.light) {
      modeStr = 'light';
    } else if (mode == ThemeMode.dark) {
      modeStr = 'dark';
    }
    _prefs?.setString('theme_mode', modeStr);
    _prefs?.setBool('is_dark_theme', mode == ThemeMode.dark);
    notifyListeners();
  }

  void setFontSize(String size) {
    _fontSize = size;
    _prefs?.setString('font_size', size);
    notifyListeners();
  }

  // Backward-compatible method
  void toggleTheme(bool isDark) {
    setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
