import 'dart:async';
import 'dart:math';

import 'package:flutter_tts/flutter_tts.dart';

import '../services/content_service.dart';

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

  /// 引擎就绪信号：Android TTS 引擎异步初始化，就绪前的 speak 会静默失败
  Completer<void>? _ready;

  /// 节流阈值：200ms
  static const int _throttleMs = 200;

  /// 鼓励台词池：优先使用内容热更下发的远端台词，回退到内置默认
  static final List<String> _defaultPraisePhrases =
      List.of(ContentService.defaultPraisePhrases);

  static final Random _random = Random();

  /// 随机取一条鼓励台词
  static String randomPraise() {
    final phrases = ContentService.instance.praisePhrases;
    final pool = phrases.isNotEmpty ? phrases : _defaultPraisePhrases;
    return pool[_random.nextInt(pool.length)];
  }

  /// 初始化 TTS 服务
  /// 设置语言 zh-CN，语速由用户设置控制，音调 1.0
  Future<void> init({double rate = 0.4}) async {
    final ready = Completer<void>();
    _ready = ready;
    try {
      final tts = FlutterTts();
      _flutterTts = tts;
      await tts.setLanguage('zh-CN');
      await tts.setSpeechRate(rate);
      await tts.setPitch(1.0);

      // Android TTS 引擎初始化是异步的：轮询语言可用性直到引擎真正就绪，
      // 避免就绪前的 speak 调用静默丢失（表现为最初几次播报没声音）
      final deadline = DateTime.now().add(const Duration(seconds: 4));
      while (DateTime.now().isBefore(deadline)) {
        try {
          final available = await tts.isLanguageAvailable('zh-CN');
          if (available == true) break;
        } catch (_) {
          // 引擎尚未绑定完成，继续等待
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      // TTS 不可用时静默降级，不崩溃
      _flutterTts = null;
    }
    // 无论成败都放行 speak，避免调用方永久挂起
    if (!ready.isCompleted) ready.complete();
  }

  /// 更新语速（0.2~0.7，注意 Android 上映射 0.5 = 引擎正常语速）
  Future<void> setRate(double rate) async {
    final tts = _flutterTts;
    if (tts == null) return;
    try {
      await tts.setSpeechRate(rate);
    } catch (_) {
      // 静默降级
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

    // 等待引擎就绪（最多 3 秒），解决启动初期前几次播报静默失败
    final ready = _ready;
    if (ready != null) {
      try {
        await ready.future.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    if (!enabled || _flutterTts == null) return;

    // 就绪后的首次调用个别引擎仍可能失败，重试一次
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final result = await _flutterTts!.speak(text);
        if (result == 1) return;
      } catch (_) {
        // 静默降级
      }
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
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
