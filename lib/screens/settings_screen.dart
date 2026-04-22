import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';

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
                  _VibrationSwitch(cs: cs, ts: ts),
                ],
              ),
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
