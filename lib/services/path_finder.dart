import 'dart:math';
import 'package:flutter/material.dart';
import '../models/cell.dart';

/// 连连看寻路算法
/// 支持 0/1/2 转弯路径查找
class PathFinder {
  /// 查找从 start 到 end 的路径，返回路径点列表 (Offset: row, col)
  /// 如果无路径返回 null
  static List<Offset>? findPath(
    Cell start,
    Cell end,
    List<List<Cell?>> grid,
  ) {
    final rows = grid.length;
    final cols = grid[0].length;

    // 0 转弯：直线
    final straight = _findStraight(start, end, grid, rows, cols);
    if (straight != null) return straight;

    // 1 转弯：单拐点
    final oneTurn = _findOneTurn(start, end, grid, rows, cols);
    if (oneTurn != null) return oneTurn;

    // 2 转弯：双拐点
    final twoTurn = _findTwoTurn(start, end, grid, rows, cols);
    if (twoTurn != null) return twoTurn;

    return null;
  }

  /// 检查指定位置是否为空（可通行）或在边界外
  static bool _isEmpty(int row, int col, List<List<Cell?>> grid, int rows, int cols) {
    // 边界外视为可通行（连连连看允许绕外围）
    if (row < 0 || row >= rows || col < 0 || col >= cols) return true;
    final cell = grid[row][col];
    return cell == null || cell.isEliminated;
  }

  /// 检查两点之间是否直线无障碍（不含端点）
  static bool _isLineClear(int r1, int c1, int r2, int c2,
      List<List<Cell?>> grid, int rows, int cols) {
    if (r1 == r2) {
      // 同行
      final minC = min(c1, c2);
      final maxC = max(c1, c2);
      for (int c = minC + 1; c < maxC; c++) {
        if (!_isEmpty(r1, c, grid, rows, cols)) return false;
      }
      return true;
    } else if (c1 == c2) {
      // 同列
      final minR = min(r1, r2);
      final maxR = max(r1, r2);
      for (int r = minR + 1; r < maxR; r++) {
        if (!_isEmpty(r, c1, grid, rows, cols)) return false;
      }
      return true;
    }
    return false;
  }

  /// 0 转弯：直线连接
  static List<Offset>? _findStraight(
    Cell start,
    Cell end,
    List<List<Cell?>> grid,
    int rows,
    int cols,
  ) {
    if (start.row != end.row && start.col != end.col) return null;
    if (_isLineClear(start.row, start.col, end.row, end.col, grid, rows, cols)) {
      return [
        Offset(start.row.toDouble(), start.col.toDouble()),
        Offset(end.row.toDouble(), end.col.toDouble()),
      ];
    }
    return null;
  }

  /// 1 转弯：一个拐点
  static List<Offset>? _findOneTurn(
    Cell start,
    Cell end,
    List<List<Cell?>> grid,
    int rows,
    int cols,
  ) {
    // 拐点1: (start.row, end.col)
    if (_isEmpty(start.row, end.col, grid, rows, cols) &&
        _isLineClear(start.row, start.col, start.row, end.col, grid, rows, cols) &&
        _isLineClear(start.row, end.col, end.row, end.col, grid, rows, cols)) {
      return [
        Offset(start.row.toDouble(), start.col.toDouble()),
        Offset(start.row.toDouble(), end.col.toDouble()),
        Offset(end.row.toDouble(), end.col.toDouble()),
      ];
    }

    // 拐点2: (end.row, start.col)
    if (_isEmpty(end.row, start.col, grid, rows, cols) &&
        _isLineClear(start.row, start.col, end.row, start.col, grid, rows, cols) &&
        _isLineClear(end.row, start.col, end.row, end.col, grid, rows, cols)) {
      return [
        Offset(start.row.toDouble(), start.col.toDouble()),
        Offset(end.row.toDouble(), start.col.toDouble()),
        Offset(end.row.toDouble(), end.col.toDouble()),
      ];
    }

    return null;
  }

  /// 2 转弯：两个拐点，扫描平行线段
  static List<Offset>? _findTwoTurn(
    Cell start,
    Cell end,
    List<List<Cell?>> grid,
    int rows,
    int cols,
  ) {
    // 水平扫描：找中间列 c，使得 start→(start.row,c)→(end.row,c)→end
    for (int c = -1; c <= cols; c++) {
      if (_isEmpty(start.row, c, grid, rows, cols) &&
          _isEmpty(end.row, c, grid, rows, cols) &&
          _isLineClear(start.row, start.col, start.row, c, grid, rows, cols) &&
          _isLineClear(start.row, c, end.row, c, grid, rows, cols) &&
          _isLineClear(end.row, c, end.row, end.col, grid, rows, cols)) {
        return [
          Offset(start.row.toDouble(), start.col.toDouble()),
          Offset(start.row.toDouble(), c.toDouble()),
          Offset(end.row.toDouble(), c.toDouble()),
          Offset(end.row.toDouble(), end.col.toDouble()),
        ];
      }
    }

    // 垂直扫描：找中间行 r，使得 start→(r,start.col)→(r,end.col)→end
    for (int r = -1; r <= rows; r++) {
      if (_isEmpty(r, start.col, grid, rows, cols) &&
          _isEmpty(r, end.col, grid, rows, cols) &&
          _isLineClear(start.row, start.col, r, start.col, grid, rows, cols) &&
          _isLineClear(r, start.col, r, end.col, grid, rows, cols) &&
          _isLineClear(r, end.col, end.row, end.col, grid, rows, cols)) {
        return [
          Offset(start.row.toDouble(), start.col.toDouble()),
          Offset(r.toDouble(), start.col.toDouble()),
          Offset(r.toDouble(), end.col.toDouble()),
          Offset(end.row.toDouble(), end.col.toDouble()),
        ];
      }
    }

    return null;
  }
}
