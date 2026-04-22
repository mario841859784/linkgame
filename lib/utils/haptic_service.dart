import 'package:vibration/vibration.dart';

/// 震动服务（单例）
/// 用于提供触觉反馈，震动参数严格按规范
class HapticService {
  HapticService._();

  static final HapticService _instance = HapticService._();
  static HapticService get instance => _instance;

  /// 是否启用震动，默认 true
  bool enabled = true;

  /// 震动指定时长（毫秒）
  Future<void> vibrate(int durationMs) async {
    if (!enabled) return;

    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      await Vibration.vibrate(duration: durationMs);
    } catch (e) {
      // 震动不可用时静默降级，不崩溃
    }
  }

  /// 选中格子震动 20ms
  Future<void> vibrateSelect() async {
    await vibrate(20);
  }

  /// 跨界滑动震动 15ms
  Future<void> vibrateCrossBoundary() async {
    await vibrate(15);
  }

  /// 匹配成功震动 50ms
  Future<void> vibrateSuccess() async {
    await vibrate(50);
  }

  /// 匹配失败震动 30ms + 间隔 50ms + 30ms
  Future<void> vibrateFail() async {
    if (!enabled) return;

    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) return;

      // 震动模式: [30ms 震动, 50ms 间隔, 30ms 震动]
      await Vibration.vibrate(pattern: [0, 30, 50, 30]);
    } catch (e) {
      // 静默降级
    }
  }

  /// 通关震动 500ms
  Future<void> vibrateWin() async {
    await vibrate(500);
  }

  /// 自动洗牌震动 200ms
  Future<void> vibrateShuffle() async {
    await vibrate(200);
  }
}
