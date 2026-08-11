import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _p;

  String language = 'en';
  bool showMap = true;
  bool showCompass = true;
  bool showQr = true;
  bool showAddress = true;
  bool use24Hour = true;
  bool showGrid = false;
  int maxWidth = 1920;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    language = _p.getString('language') ?? 'en';
    showMap = _p.getBool('showMap') ?? true;
    showCompass = _p.getBool('showCompass') ?? true;
    showQr = _p.getBool('showQr') ?? true;
    showAddress = _p.getBool('showAddress') ?? true;
    use24Hour = _p.getBool('use24Hour') ?? true;
    showGrid = _p.getBool('showGrid') ?? false;
    maxWidth = _p.getInt('maxWidth') ?? 1920;
    notifyListeners();
  }

  Future<void> setLanguage(String v) async {
    language = v;
    await _p.setString('language', v);
    notifyListeners();
  }

  Future<void> setShowMap(bool v) async {
    showMap = v;
    await _p.setBool('showMap', v);
    notifyListeners();
  }

  Future<void> setShowCompass(bool v) async {
    showCompass = v;
    await _p.setBool('showCompass', v);
    notifyListeners();
  }

  Future<void> setShowQr(bool v) async {
    showQr = v;
    await _p.setBool('showQr', v);
    notifyListeners();
  }

  Future<void> setShowAddress(bool v) async {
    showAddress = v;
    await _p.setBool('showAddress', v);
    notifyListeners();
  }

  Future<void> setUse24Hour(bool v) async {
    use24Hour = v;
    await _p.setBool('use24Hour', v);
    notifyListeners();
  }

  Future<void> setShowGrid(bool v) async {
    showGrid = v;
    await _p.setBool('showGrid', v);
    notifyListeners();
  }

  Future<void> setMaxWidth(int v) async {
    maxWidth = v;
    await _p.setInt('maxWidth', v);
    notifyListeners();
  }
}
