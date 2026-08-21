import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart';

class AppState extends ChangeNotifier {
  String _lang = 'en';
  double _speed = 1.0;
  int _repeat = 1;
  ThemeMode _themeMode = ThemeMode.system;
  double _zoom = 1.0;
  String get lang => _lang;
  double get speed => _speed;
  int get repeat => _repeat;
  ThemeMode get themeMode => _themeMode;
  double get zoom => _zoom;

  AppState() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('ui_lang') ?? 'en';
    _speed = prefs.getDouble('ui_speed') ?? 1.0;
    _repeat = prefs.getInt('ui_repeat') ?? 1;
    _zoom = prefs.getDouble('ui_zoom') ?? 1.0;
    final theme = prefs.getString('ui_theme') ?? 'system';
    _themeMode =
        theme == 'dark'
            ? ThemeMode.dark
            : theme == 'light'
            ? ThemeMode.light
            : ThemeMode.system;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final v =
        mode == ThemeMode.dark
            ? 'dark'
            : mode == ThemeMode.light
            ? 'light'
            : 'system';
    await prefs.setString('ui_theme', v);
  }

  Future<void> setLang(String lang) async {
    _lang = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_lang', lang);
  }

  Future<void> setSpeed(double speed) async {
    _speed = speed;
    AudioService.instance.speed = speed;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ui_speed', speed);
  }

  Future<void> setRepeat(int repeat) async {
    _repeat = repeat;
    AudioService.instance.repeat = repeat;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ui_repeat', repeat);
  }

  Future<void> setZoom(double zoom) async {
    _zoom = zoom.clamp(0.8, 2.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ui_zoom', _zoom);
  }

  bool get isRtl => _lang == 'ar';
}
