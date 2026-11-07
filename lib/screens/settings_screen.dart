import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../utils/tts_service.dart';

/// 设置页面 — 适老化大字号、卡片分组、高对比度
/// "Warm Clarity" 设计语言
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 32),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
        title: const Text('设置'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 难度选择区
            _SectionHeader(
              icon: Icons.grid_on,
              title: '难度选择',
              subtitle: '选择棋盘大小，格子越多越有挑战',
              cs: cs,
              ts: ts,
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _DifficultyRadio(
                    label: '简单',
                    detail: '4 列 × 7 行',
                    value: '简单',
                    icon: Icons.sentiment_satisfied,
                    cs: cs,
                    ts: ts,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _DifficultyRadio(
                    label: '普通',
                    detail: '6 列 × 9 行',
                    value: '普通',
                    icon: Icons.sentiment_neutral,
                    cs: cs,
                    ts: ts,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _DifficultyRadio(
                    label: '困难',
                    detail: '8 列 × 10 行',
                    value: '困难',
                    icon: Icons.sentiment_very_satisfied,
                    cs: cs,
                    ts: ts,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // 反馈设置区
            _SectionHeader(
              icon: Icons.touch_app,
              title: '反馈设置',
              subtitle: '开启语音和震动，操作更安心',
              cs: cs,
              ts: ts,
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _TtsSwitch(cs: cs, ts: ts),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _TtsRateSlider(cs: cs, ts: ts),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _VibrationSwitch(cs: cs, ts: ts),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 版本与更新
            _SectionHeader(
              icon: Icons.system_update_alt_rounded,
              title: '版本与更新',
              subtitle: '有新版本时可以直接在这里升级',
              cs: cs,
              ts: ts,
            ),
            const SizedBox(height: 12),
            Card(
              clipBehavior: Clip.antiAlias,
              child: _UpdateTile(cs: cs, ts: ts),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// 分区标题
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme ts;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.ts,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 28, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ts.titleLarge?.copyWith(
                  color: cs.onSurface,
                  fontSize: 24,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: ts.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 难度单选 — 整合在 Card 内
class _DifficultyRadio extends StatelessWidget {
  final String label;
  final String detail;
  final String value;
  final IconData icon;
  final ColorScheme cs;
  final TextTheme ts;

  const _DifficultyRadio({
    required this.label,
    required this.detail,
    required this.value,
    required this.icon,
    required this.cs,
    required this.ts,
  });

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isSelected = settings.difficulty == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          settings.difficulty = value;
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primary.withValues(alpha:0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              // 文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: ts.titleMedium?.copyWith(
                        color: isSelected ? cs.primary : cs.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: ts.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // 选中标记
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? cs.primary : cs.outline,
                    width: isSelected ? 8 : 2,
                  ),
                  color: isSelected ? cs.primary : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TTS 开关
class _TtsSwitch extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme ts;

  const _TtsSwitch({required this.cs, required this.ts});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return SwitchListTile(
      title: Text(
        '语音播报',
        style: ts.titleMedium?.copyWith(fontSize: 22),
      ),
      subtitle: Text(
        '滑到格子上时朗读图案名称，帮助识别',
        style: ts.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 18,
        ),
      ),
      value: settings.isTtsEnabled,
      onChanged: (value) {
        settings.isTtsEnabled = value;
      },
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.tertiaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          settings.isTtsEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          size: 28,
          color: cs.onTertiaryContainer,
        ),
      ),
      activeThumbColor: cs.tertiary,
    );
  }
}

/// 语速描述（Android 映射：flutter 0.5 = 引擎正常语速，默认 0.4 略慢）
String _ttsRateLabel(double rate) {
  if (rate < 0.35) return '很慢';
  if (rate < 0.45) return '较慢';
  if (rate < 0.55) return '正常';
  return '较快';
}

/// TTS 语速滑杆
class _TtsRateSlider extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme ts;

  const _TtsRateSlider({required this.cs, required this.ts});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.speed_rounded,
                  size: 28,
                  color: cs.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '语速',
                  style: ts.titleMedium?.copyWith(fontSize: 22),
                ),
              ),
              Text(
                _ttsRateLabel(settings.ttsRate),
                style: ts.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          Slider(
            value: settings.ttsRate,
            min: 0.2,
            max: 0.7,
            divisions: 10,
            label: _ttsRateLabel(settings.ttsRate),
            onChanged: (value) {
              settings.ttsRate = value;
              TtsService.instance.setRate(value);
            },
          ),
          Text(
            '朗读快慢，向左更慢更清楚',
            style: ts.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 震动开关
class _VibrationSwitch extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme ts;

  const _VibrationSwitch({required this.cs, required this.ts});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return SwitchListTile(
      title: Text(
        '震动反馈',
        style: ts.titleMedium?.copyWith(fontSize: 22),
      ),
      subtitle: Text(
        '滑动跨越格子边界和匹配成功时提供震动提示',
        style: ts.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontSize: 18,
        ),
      ),
      value: settings.isVibrationEnabled,
      onChanged: (value) {
        settings.isVibrationEnabled = value;
      },
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          settings.isVibrationEnabled
              ? Icons.vibration_rounded
              : Icons.do_not_disturb_on_rounded,
          size: 28,
          color: cs.onSecondaryContainer,
        ),
      ),
      activeThumbColor: cs.secondary,
    );
  }
}

/// 版本与更新卡片 — 检查 / 下载 / 安装三态
class _UpdateTile extends StatefulWidget {
  final ColorScheme cs;
  final TextTheme ts;

  const _UpdateTile({required this.cs, required this.ts});

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  bool _busy = false;
  RemoteRelease? _release;
  double _progress = 0;
  String? _apkPath;
  String? _status;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    UpdateService.instance.currentVersionName().then((v) {
      if (mounted) setState(() => _currentVersion = v);
    });
  }

  Future<void> _onTap() async {
    // 已下载完成 → 安装
    if (_apkPath != null) {
      await UpdateService.instance.installApk(_apkPath!);
      return;
    }
    // 已发现新版本 → 下载
    if (_release != null) {
      await _download();
      return;
    }
    // 否则检查
    setState(() {
      _busy = true;
      _status = null;
    });
    final outcome = await UpdateService.instance.checkLatest();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _release = outcome.release;
      _status = !outcome.succeeded
          ? '检查失败，请检查网络后重试'
          : outcome.release == null
              ? '已是最新版本'
              : null;
    });
  }

  Future<void> _download() async {
    final release = _release;
    if (release == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _status = null;
    });
    try {
      final path = await UpdateService.instance
          .downloadApk(release, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _busy = false;
        _apkPath = path;
      });
      await UpdateService.instance.installApk(path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '下载失败，请稍后重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    final ts = widget.ts;

    String title;
    String subtitle;
    if (_apkPath != null) {
      title = '安装新版本';
      subtitle = '下载完成，点击安装（可能需要在系统设置允许安装）';
    } else if (_release != null) {
      title = _busy ? '正在下载 ${(_progress * 100).round()}%' : '升级到新版本 ${_release!.versionName}';
      subtitle = _busy ? '下载中，请稍候' : '点击立即下载升级';
    } else {
      title = '检查更新';
      subtitle = '当前版本 $_currentVersion${_status == null ? '' : ' · $_status'}';
    }

    final enabled = !_busy;

    return Column(
      children: [
        ListTile(
          title: Text(title, style: ts.titleMedium?.copyWith(fontSize: 22)),
          subtitle: Text(
            subtitle,
            style: ts.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 18,
            ),
          ),
          enabled: enabled,
          onTap: _onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _apkPath != null || _release != null
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _apkPath != null
                  ? Icons.install_mobile_rounded
                  : _release != null
                      ? Icons.download_rounded
                      : Icons.update_rounded,
              size: 28,
              color: _apkPath != null || _release != null
                  ? cs.onPrimaryContainer
                  : cs.onSurfaceVariant,
            ),
          ),
        ),
        if (_busy && _release != null)
          LinearProgressIndicator(
            value: _progress > 0 ? _progress : null,
            minHeight: 4,
          ),
      ],
    );
  }
}
