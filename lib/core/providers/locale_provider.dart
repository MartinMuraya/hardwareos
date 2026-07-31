import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code') ?? 'en';

    if (langCode == 'sw_KE') {
      _locale = const Locale('sw', 'KE');
    } else {
      _locale = Locale(langCode);
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.toString(); // e.g. "en", "sw", "sw_KE"
    if (!['en', 'sw', 'sw_KE'].contains(code)) return;
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    notifyListeners();
  }
}
