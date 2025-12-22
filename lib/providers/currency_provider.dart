import 'package:flutter/material.dart';

class CurrencyProvider extends ChangeNotifier {
  String _currencyCode = 'USD';

  String get currencyCode => _currencyCode;

  void setCurrency(String code) {
    if (_currencyCode != code) {
      _currencyCode = code;
      notifyListeners();
    }
  }
}
