import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 滑动过程中的实时连接线绘制器
///
/// [points] 为 Stack 坐标系下的像素点（已含网格偏移与格子中心换算）：
/// - [matchable] == true（可消除）：金色发光实线，样式与消除后的路径一致
/// - [matchable] == false（不能消除）：红色虚线，直线连接起点与当前块
class LiveLinkPainter extends CustomPainter {
  final List<Offset> points;
  final bool matchable;
  final Color validColor;
  final Color invalidColor;

  LiveLinkPainter({
    required this.points,
    required this.matchable,
    required this.validColor,
    required this.invalidColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final pathObj = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      pathObj.lineTo(points[i].dx, points[i].dy);
    }

    if (matchable) {
      // 发光层 + 主线（与消除路径同款视觉语言）
      final glowPaint = Paint()
        ..color = validColor.withValues(alpha: 0.3)
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final mainPaint = Paint()
        ..color = validColor
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(pathObj, glowPaint);
      canvas.drawPath(pathObj, mainPaint);
    } else {
      // 红色虚线
      final dashPaint = Paint()
        ..color = invalidColor.withValues(alpha: 0.85)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (final segment in _dashSegments(pathObj, dash: 10, gap: 9)) {
        canvas.drawLine(segment.$1, segment.$2, dashPaint);
      }
    }

    // 起点标记
    canvas.drawCircle(points.first, 7, Paint()..color = validColor.withValues(alpha: 0.9));
  }

  /// 沿路径按 (dash, gap) 生成虚线线段
  Iterable<(Offset, Offset)> _dashSegments(
    Path path, {
    required double dash,
    required double gap,
  }) sync* {
    final period = dash + gap;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = math.min(distance + dash, metric.length);
        final p1 = metric.getTangentForOffset(start)?.position;
        final p2 = metric.getTangentForOffset(end)?.position;
        if (p1 != null && p2 != null) {
          yield (p1, p2);
        }
        distance += period;
      }
    }
  }

  @override
  bool shouldRepaint(covariant LiveLinkPainter oldDelegate) {
    return oldDelegate.matchable != matchable ||
        oldDelegate.validColor != validColor ||
        oldDelegate.invalidColor != invalidColor ||
        !oldDelegate._samePoints(points);
  }

  bool _samePoints(List<Offset> other) {
    if (points.length != other.length) return false;
    for (int i = 0; i < points.length; i++) {
      if (points[i] != other[i]) return false;
    }
    return true;
  }
}
