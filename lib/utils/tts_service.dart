import 'package:flutter_tts/flutter_tts.dart';

/// TTS 语音播报服务（单例）
/// 用于播报中文格子标签，支持节流控制防高频卡顿
class TtsService {
  TtsService._();

  static final TtsService _instance = TtsService._();
  static TtsService get instance => _instance;

  /// 是否启用 TTS 播报，默认 true
  bool enabled = true;

  FlutterTts? _flutterTts;
  DateTime? _lastSpeakTime;

  /// 节流阈值：200ms
  static const int _throttleMs = 200;

  /// 初始化 TTS 服务
  /// 设置语言 zh-CN，语速 0.8，音调 1.0
  Future<void> init() async {
    try {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage('zh-CN');
      await _flutterTts!.setSpeechRate(0.8);
      await _flutterTts!.setPitch(1.0);
    } catch (e) {
      // TTS 不可用时静默降级，不崩溃
      _flutterTts = null;
    }
  }

  /// 播报文本，节流控制（距上次播报 < 200ms 时跳过）
  Future<void> speak(String text) async {
    if (!enabled || _flutterTts == null) return;

    final now = DateTime.now();
    if (_lastSpeakTime != null) {
      final diff = now.difference(_lastSpeakTime!).inMilliseconds;
      if (diff < _throttleMs) return;
    }

    _lastSpeakTime = now;
    try {
      await _flutterTts!.speak(text);
    } catch (e) {
      // 播报失败静默降级
    }
  }

  /// 停止当前播报
  Future<void> stop() async {
    if (_flutterTts == null) return;
    try {
      await _flutterTts!.stop();
    } catch (e) {
      // 静默降级
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_flutterTts != null) {
      try {
        await _flutterTts!.stop();
      } catch (e) {
        // 静默降级
      }
      _flutterTts = null;
    }
  }
}
