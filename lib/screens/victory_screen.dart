import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 粒子彩纸 Widget — 通关庆祝动效（增强版）
class ParticleWidget extends StatefulWidget {
  final bool active;

  const ParticleWidget({super.key, this.active = true});

  @override
  State<ParticleWidget> createState() => _ParticleWidgetState();
}

class _ParticleWidgetState extends State<ParticleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];

  // 暖色调庆祝配色 — 避免 AI 感的紫蓝渐变
  static const _colors = [
    Color(0xFFFFD700), // 金
    Color(0xFFFF6B35), // 橙
    Color(0xFFFF4757), // 红
    Color(0xFF2ED573), // 绿
    Color(0xFF1E90FF), // 蓝
    Color(0xFFFFA502), // 橘
    Color(0xFFFF6348), // 珊瑚
    Color(0xFF7BED9F), // 浅绿
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (widget.active) {
      _controller.repeat();
    }

    // 生成 80 个随机粒子 — 更大更密
    final rng = math.Random();
    for (int i = 0; i < 80; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: -rng.nextDouble() * 0.3, // 从顶部上方开始
        size: rng.nextDouble() * 12 + 5, // 5-17px
        color: _colors[rng.nextInt(_colors.length)],
        speed: rng.nextDouble() * 0.4 + 0.15,
        rotation: rng.nextDouble() * math.pi * 2,
        rotationSpeed: (rng.nextDouble() - 0.5) * 6,
        wobble: rng.nextDouble() * math.pi * 2,
        wobbleSpeed: rng.nextDouble() * 3 + 1,
        shape: rng.nextInt(3), // 0=矩形, 1=圆形, 2=星形
      ));
    }
  }

  @override
  void didUpdateWidget(ParticleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double size;
  final Color color;
  final double speed;
  final double rotation;
  final double rotationSpeed;
  final double wobble;
  final double wobbleSpeed;
  final int shape;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.speed,
    required this.rotation,
    required this.rotationSpeed,
    required this.wobble,
    required this.wobbleSpeed,
    required this.shape,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // 下落动画
      final animatedY = (p.y + progress * p.speed) % 1.3;
      // 左右摇摆
      final wobble = math.sin(progress * math.pi * p.wobbleSpeed + p.wobble) * 0.04;
      final animatedX = (p.x + wobble) % 1.0;
      final rotation = p.rotation + progress * p.rotationSpeed;

      canvas.save();
      canvas.translate(animatedX * size.width, animatedY * size.height);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = p.color.withValues(alpha:0.85)
        ..style = PaintingStyle.fill;

      switch (p.shape) {
        case 0: // 矩形彩纸
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * 0.6,
            ),
            paint,
          );
          break;
        case 1: // 圆点
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
          break;
        case 2: // 星形（简化为菱形）
          canvas.drawPath(
            Path()
              ..moveTo(0, -p.size * 0.5)
              ..lineTo(p.size * 0.3, 0)
              ..lineTo(0, p.size * 0.5)
              ..lineTo(-p.size * 0.3, 0)
              ..close(),
            paint,
          );
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

/// 得分数字翻牌动画
class _ScoreCounter extends StatefulWidget {
  final int targetScore;

  const _ScoreCounter({required this.targetScore});

  @override
  State<_ScoreCounter> createState() => _ScoreCounterState();
}

class _ScoreCounterState extends State<_ScoreCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = IntTween(begin: 0, end: widget.targetScore).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_animation.value}',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w900,
                fontSize: 56,
              ),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}

/// 通关庆祝页面 — 适老化大字号、高对比度、增强庆典感
class VictoryScreen extends StatelessWidget {
  final int finalScore;

  const VictoryScreen({super.key, required this.finalScore});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // 粒子彩纸背景层
            const Positioned.fill(
              child: ParticleWidget(),
            ),

            // 内容层
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 奖杯动画
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.secondaryContainer.withValues(alpha:0.4),
                            boxShadow: [
                              BoxShadow(
                                color: cs.secondary.withValues(alpha:0.3),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            size: 88,
                            color: Color(0xFFFFB300),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // 恭喜通关
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      '恭喜通关！',
                      style: ts.displayMedium?.copyWith(
                        color: cs.primary,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 得分标题
                  Text(
                    '最终得分',
                    style: ts.titleLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // 得分数字 — 翻牌动画
                  _ScoreCounter(targetScore: finalScore),
                  const SizedBox(height: 40),

                  // 再来一局按钮
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                      },
                      icon: const Icon(Icons.replay_rounded, size: 36),
                      label: Text(
                        '再来一局',
                        style: ts.labelLarge,
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(72),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 返回主页按钮
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                      },
                      icon: const Icon(Icons.home_rounded, size: 36),
                      label: Text(
                        '返回主页',
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
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
