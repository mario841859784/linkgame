import 'package:flutter/material.dart';

/// 指尖悬浮放大镜 Widget
/// 手指按下并移动超过 10dp 后显示，松手隐藏
/// Y 偏移 -80dp，确保手指不遮挡目标格子
///
/// "Warm Clarity" 设计：
/// - 多层阴影营造深度感
/// - 渐变边框增加精致度
/// - Emoji 带文字标签
class MagnifierWidget extends StatelessWidget {
  final String emoji;
  final Offset position;
  final double cellSize;

  const MagnifierWidget({
    super.key,
    required this.emoji,
    required this.position,
    required this.cellSize,
  });

  /// 放大镜直径 = cellSize * 1.5
  double get diameter => cellSize * 1.5;

  /// Emoji 字号 = cellSize * 0.75
  double get emojiFontSize => cellSize * 0.75;

  /// Y 偏移 -80dp（手指不遮挡目标格子）
  double get offsetY => position.dy - 80;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Positioned(
      left: position.dx - diameter / 2,
      top: offsetY - diameter / 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: cs.surface,
          shape: BoxShape.circle,
          // 多层阴影 — 营造悬浮深度
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha:0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            // 内阴影效果（用白色模拟）
            BoxShadow(
              color: Colors.white.withValues(alpha:0.5),
              blurRadius: 4,
              offset: const Offset(-2, -2),
            ),
          ],
          // 渐变边框
          border: Border.all(
            color: cs.outline.withValues(alpha:0.6),
            width: 3,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 内部装饰圆环
            Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: cs.primary.withValues(alpha:0.15),
                  width: 1.5,
                ),
              ),
            ),
            // Emoji
            Center(
              child: Text(
                emoji,
                style: TextStyle(
                  fontSize: emojiFontSize,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
