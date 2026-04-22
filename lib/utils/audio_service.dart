import 'package:audioplayers/audioplayers.dart';

/// 音效服务（单例）
/// 用于播放游戏音效，仅支持 WAV 格式
class AudioService {
  AudioService._();

  static final AudioService _instance = AudioService._();
  static AudioService get instance => _instance;

  /// 是否启用音效，默认 true
  bool enabled = true;

  AudioPlayer? _player;

  /// 初始化音效服务
  Future<void> init() async {}

  /// 播放音效
  /// [fileName] 音效文件名，不含扩展名（自动追加 .wav）
  Future<void> play(String fileName) async {
    if (!enabled) return;

    try {
      _player?.dispose();
      _player = AudioPlayer();
      await _player!.play(AssetSource('audio/$fileName.wav'));
      _player!.onPlayerComplete.listen((_) {
        _player?.dispose();
        _player = null;
      });
    } catch (e) {
      _player?.dispose();
      _player = null;
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
