import 'package:flutter/widgets.dart';

/// App 生命周期观察者
/// 继承 WidgetsBindingObserver，监听前后台切换
/// 用途：切后台暂停计时 + 停止 TTS，切回前台恢复
class AppLifecycleObserver with WidgetsBindingObserver {
  VoidCallback? onPause;
  VoidCallback? onResume;

  AppLifecycleObserver({this.onPause, this.onResume});

  /// 注册观察者
  void init() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// 移除观察者
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        onPause?.call();
        break;
      case AppLifecycleState.resumed:
        onResume?.call();
        break;
      default:
        break;
    }
  }
}
