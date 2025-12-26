import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {

  ThemeMode get themeMode => SettingsService().themeMode;

  void toggleTheme() {
    if (themeMode == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.light);
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (themeMode != mode) {
      SettingsService().setThemeMode(mode).then((_) {
        notifyListeners();
      });
    }
  }
}
