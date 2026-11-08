import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/utils/download_speed_monitor.dart';

void main() {
  group('DownloadSpeedMonitor', () {
    test('样本不足（窗口未填满）不判定停滞', () {
      var t = DateTime(2026, 1, 1);
      final m = DownloadSpeedMonitor(now: () => t);
      m.sample(0);
      t = t.add(const Duration(seconds: 7, milliseconds: 900));
      m.sample(100);
      expect(m.isStalled, isFalse);
    });

    test('窗口内平均速率低于阈值判定停滞', () {
      var t = DateTime(2026, 1, 1);
      final m = DownloadSpeedMonitor(now: () => t);
      m.sample(0);
      t = t.add(const Duration(seconds: 8));
      m.sample(100); // 12.5 B/s << 32KB/s
      expect(m.isStalled, isTrue);
    });

    test('高速率不判定停滞', () {
      var t = DateTime(2026, 1, 1);
      final m = DownloadSpeedMonitor(now: () => t);
      m.sample(0);
      t = t.add(const Duration(seconds: 8));
      m.sample(1024 * 1024); // 128KB/s > 32KB/s
      expect(m.isStalled, isFalse);
    });

    test('只有一条样本不判定停滞', () {
      final m = DownloadSpeedMonitor(now: () => DateTime(2026, 1, 1));
      m.sample(100);
      expect(m.isStalled, isFalse);
    });

    test('样本按上限裁剪：网络恢复后不再判定停滞', () {
      var t = DateTime(2026, 1, 1);
      final m = DownloadSpeedMonitor(now: () => t);
      m.sample(0);
      t = t.add(const Duration(seconds: 9));
      m.sample(100);
      expect(m.isStalled, isTrue);
      // 之后每秒 128KB/s 的高速灌入，慢速样本滑出窗口后恢复
      for (var i = 1; i <= 30; i++) {
        t = t.add(const Duration(seconds: 1));
        m.sample(100 + i * 128 * 1024);
      }
      expect(m.isStalled, isFalse);
    });

    test('冻结连接：长时间无数据后只来一点也算停滞', () {
      var t = DateTime(2026, 1, 1);
      final m = DownloadSpeedMonitor(now: () => t);
      m.sample(0);
      t = t.add(const Duration(seconds: 30));
      m.sample(10);
      expect(m.isStalled, isTrue);
    });
  });
}
