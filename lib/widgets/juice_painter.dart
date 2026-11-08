import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 消除爆点粒子
class JuiceParticle {
  Offset pos;
  Offset vel;
  final Color color;
  final double size;
  final bool round;
  double life;
  final double maxLife;
  double angle;
  final double spin;

  JuiceParticle({
    required this.pos,
    required this.vel,
    required this.color,
    required this.size,
    required this.round,
    required this.maxLife,
  })  : life = maxLife,
        angle = math.Random().nextDouble() * math.pi * 2,
        spin = (math.Random().nextDouble() - 0.5) * 10;
}

/// +N 跳分
class ScoreFloat {
  final Offset origin;
  final String text;
  final Color color;
  double age;
  final double maxAge;

  ScoreFloat({
    required this.origin,
    required this.text,
    required this.color,
    this.maxAge = 0.9,
  }) : age = 0;
}

/// 画面抖动帧：粒子 + 跳分的快照（ValueNotifier 持有，JuicePainter 绘制）
class JuiceFrame {
  final List<JuiceParticle> particles;
  final List<ScoreFloat> floats;
  const JuiceFrame({required this.particles, required this.floats});
}

/// 消除爽点层：爆点粒子 + 上飘跳分（只重绘本层）
class JuicePainter extends CustomPainter {
  final JuiceFrame frame;

  JuicePainter({required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in frame.particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: t)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(p.pos.dx, p.pos.dy);
      canvas.rotate(p.angle);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size * t, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size * 1.4 * t, height: p.size * t),
          paint,
        );
      }
      canvas.restore();
    }

    for (final f in frame.floats) {
      final t = (f.age / f.maxAge).clamp(0.0, 1.0);
      final rise = 46.0 * Curves.easeOut.transform(t);
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: f.color.withValues(alpha: 1.0 - t),
            shadows: [
              Shadow(
                  color: Colors.black.withValues(alpha: 0.25 * (1 - t)),
                  blurRadius: 6),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, f.origin + Offset(-tp.width / 2, -rise));
    }
  }

  @override
  bool shouldRepaint(covariant JuicePainter oldDelegate) => true;
}
