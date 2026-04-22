import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/game_state.dart';
import '../services/settings_service.dart';
import '../models/emoji_themes.dart';
import 'play_session_screen.dart';
import 'settings_screen.dart';

/// 主菜单页面 — 温暖欢迎感 + 超大触控域
/// "Warm Clarity" 设计语言：深海军蓝 + 琥珀金点缀
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                cs.primary.withValues(alpha:0.06),
                cs.surface,
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 装饰性 Emoji 行 — 增加游戏感
                  _buildEmojiRow(cs),
                  const SizedBox(height: 32),

                  // 标题区
                  Text(
                    '连连看',
                    style: ts.displayMedium?.copyWith(
                      color: cs.primary,
                      letterSpacing: 6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '找到相同的图案，连线消除',
                    style: ts.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 72),

                  // 开始游戏按钮
                  _buildPrimaryButton(context, cs, ts),
                  const SizedBox(height: 20),

                  // 设置按钮
                  _buildSecondaryButton(context, cs, ts),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 装饰性 Emoji 行 — 展示游戏元素
  Widget _buildEmojiRow(ColorScheme cs) {
    const emojis = ['🍎', '🐶', '🌸', '🍕', '🚗', '⚽'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: emojis.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            e,
            style: const TextStyle(fontSize: 32),
          ),
        );
      }).toList(),
    );
  }

  /// 主按钮 — 开始游戏
  Widget _buildPrimaryButton(
    BuildContext context,
    ColorScheme cs,
    TextTheme ts,
  ) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          final settings = context.read<SettingsService>();
          context.read<GameState>().initializeGrid(
                settings.difficulty,
                EmojiTheme.fruits,
              );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PlaySessionScreen(),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow, size: 36),
        label: Text(
          '开始游戏',
          style: ts.labelLarge,
        ),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(72),
          padding: const EdgeInsets.symmetric(vertical: 8),
          backgroundColor: const Color(0xFFFFB300), // 明亮琥珀金暖色
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  /// 副按钮 — 设置
  Widget _buildSecondaryButton(
    BuildContext context,
    ColorScheme cs,
    TextTheme ts,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const SettingsScreen(),
            ),
          );
        },
        icon: const Icon(Icons.settings, size: 36),
        label: Text(
          '设置',
          style: ts.labelLarge?.copyWith(
            color: cs.primary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(72),
          padding: const EdgeInsets.symmetric(vertical: 8),
          side: BorderSide(color: cs.primary, width: 2.5),
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
