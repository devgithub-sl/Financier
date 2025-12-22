import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() {
    return _instance;
  }

  SettingsService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Keys
  static const String _keyCurrency = 'selected_currency';
  static const String _keyUiMode = 'ui_mode';

  // Currency
  String get currencyCode => _prefs.getString(_keyCurrency) ?? 'USD';

  Future<void> setCurrencyCode(String value) async {
    await _prefs.setString(_keyCurrency, value);
  }

  // Theme
  ThemeMode get themeMode {
    final mode = _prefs.getString(_keyUiMode);
    if (mode == 'light') return ThemeMode.light;
    if (mode == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
      default:
        value = 'system';
        break;
    }
    await _prefs.setString(_keyUiMode, value);
  }
}
