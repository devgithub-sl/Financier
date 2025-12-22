import 'package:flutter/material.dart';

import '../services/settings_service.dart';

class CurrencyProvider extends ChangeNotifier {
  String get currencyCode => SettingsService().currencyCode;

  void setCurrency(String code) {
    if (SettingsService().currencyCode != code) {
      SettingsService().setCurrencyCode(code).then((_) {
        notifyListeners();
      });
    }
  }
}
