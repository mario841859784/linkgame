/// 流式下载的慢速监视器
///
/// 按数据块到达做时间门控采样（默认每 500ms 至多记一个样本），保留最近的
/// 样本窗口；当首个与最新样本的时间跨度达到 [window] 且窗口内平均速率低于
/// [minBytesPerSecond] 时判定「停滞」，由调用方断开当前连接并切换下载源。
///
/// 时间源可注入（测试用假时钟驱动采样序列）；生产环境用系统时钟。
class DownloadSpeedMonitor {
  DownloadSpeedMonitor({
    this.window = const Duration(seconds: 8),
    this.minBytesPerSecond = 32 * 1024,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// 判定停滞所需的最小观测跨度
  final Duration window;

  /// 窗口内平均速率低于该值（字节/秒）判定停滞
  final int minBytesPerSecond;

  final DateTime Function() _now;

  /// 相邻样本的最小间隔（限制样本数量，高速下载下不必每块都记）
  static const Duration _minSampleInterval = Duration(milliseconds: 500);

  /// 样本上限：24 个 × 500ms 门控 = 至少覆盖 12s，宽于默认 8s 窗口
  static const int _maxSamples = 24;

  final List<MapEntry<DateTime, int>> _samples = [];

  /// 记录一个累计字节样本（[cumulativeBytes] 为含续传前缀的累计值）
  void sample(int cumulativeBytes) {
    final t = _now();
    if (_samples.isNotEmpty &&
        t.difference(_samples.last.key) < _minSampleInterval) {
      return;
    }
    _samples.add(MapEntry(t, cumulativeBytes));
    if (_samples.length > _maxSamples) _samples.removeAt(0);
  }

  /// 窗口已填满且窗口内平均速率低于阈值
  bool get isStalled {
    if (_samples.length < 2) return false;
    final elapsed = _samples.last.key.difference(_samples.first.key);
    if (elapsed < window) return false;
    final bytes = _samples.last.value - _samples.first.value;
    return bytes < minBytesPerSecond * elapsed.inMilliseconds / 1000;
  }
}
