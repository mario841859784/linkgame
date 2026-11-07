import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_service.dart';

/// 设置服务 (ChangeNotifier)
/// 使用 shared_preferences 持久化用户设置
class SettingsService extends ChangeNotifier {
  bool _isTtsEnabled = true;
  bool _isVibrationEnabled = true;
  String _difficulty = '简单';
  double _ttsRate = 0.4;

  bool get isTtsEnabled => _isTtsEnabled;
  bool get isVibrationEnabled => _isVibrationEnabled;
  String get difficulty => _difficulty;
  double get ttsRate => _ttsRate;

  // SharedPreferences 键名
  static const String _keyTts = 'tts_enabled';
  static const String _keyVibration = 'vibration_enabled';
  static const String _keyDifficulty = 'difficulty';
  static const String _keyTtsRate = 'tts_rate';

  /// 从持久化存储加载设置
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isTtsEnabled = prefs.getBool(_keyTts) ?? true;
      _isVibrationEnabled = prefs.getBool(_keyVibration) ?? true;
      _difficulty = prefs.getString(_keyDifficulty) ?? '简单';
      // 用户未手动调过语速时，跟随内容热更下发的默认语速
      _ttsRate = prefs.getDouble(_keyTtsRate) ??
          ContentService.instance.ttsRateDefault;
      notifyListeners();
    } catch (e) {
      // 加载失败时使用默认值，不崩溃
      debugPrint('SettingsService: 加载设置失败 - $e');
    }
  }

  /// 保存设置到持久化存储
  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyTts, _isTtsEnabled);
      await prefs.setBool(_keyVibration, _isVibrationEnabled);
      await prefs.setString(_keyDifficulty, _difficulty);
      await prefs.setDouble(_keyTtsRate, _ttsRate);
    } catch (e) {
      debugPrint('SettingsService: 保存设置失败 - $e');
    }
  }

  set isTtsEnabled(bool value) {
    _isTtsEnabled = value;
    saveSettings();
    notifyListeners();
  }

  set isVibrationEnabled(bool value) {
    _isVibrationEnabled = value;
    saveSettings();
    notifyListeners();
  }

  set difficulty(String value) {
    _difficulty = value;
    saveSettings();
    notifyListeners();
  }

  set ttsRate(double value) {
    _ttsRate = value.clamp(0.2, 0.7);
    saveSettings();
    notifyListeners();
  }
}
