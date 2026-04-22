import 'dart:math';
import 'package:flutter/material.dart';
import '../models/cell.dart';
import '../models/emoji_themes.dart';
import 'path_finder.dart';

/// 难度配置
class DifficultyConfig {
  final String name;
  final int cols;
  final int rows;

  const DifficultyConfig({
    required this.name,
    required this.cols,
    required this.rows,
  });

  static const easy = DifficultyConfig(name: '简单', cols: 4, rows: 7);
  static const normal = DifficultyConfig(name: '普通', cols: 6, rows: 9);
  static const hard = DifficultyConfig(name: '困难', cols: 8, rows: 10);

  static DifficultyConfig byName(String name) {
    switch (name) {
      case '简单':
        return easy;
      case '普通':
        return normal;
      case '困难':
        return hard;
      default:
        return normal;
    }
  }
}

/// 游戏状态管理
class GameState extends ChangeNotifier {
  // 网格数据
  List<List<Cell?>> grid = [];

  // 游戏状态
  int score = 0;
  String difficulty = '简单';
  Cell? selectedCell;
  int timeElapsed = 0;
  bool isPlaying = false;
  bool _isVictory = false;

  // 最近一次成功匹配的路径（用于可视化）
  List<Offset>? currentPath;

  // 当前主题
  EmojiTheme currentTheme = EmojiTheme.fruits;

  /// 是否通关
  bool get isVictory => _isVictory;

  /// 清除胜利标志
  void clearVictory() {
    _isVictory = false;
  }

  /// 初始化网格
  void initializeGrid(String diff, EmojiTheme theme) {
    final config = DifficultyConfig.byName(diff);
    difficulty = diff;
    currentTheme = theme;
    score = 0;
    selectedCell = null;
    timeElapsed = 0;
    isPlaying = true;
    _isVictory = false;

    final totalCells = config.cols * config.rows;
    final emojis = theme.emojis;
    final ttsLabels = theme.ttsLabels;

    // 每个 emoji 需要出现偶数次（配对）
    final pairsPerEmoji = totalCells ~/ (emojis.length * 2);
    final remainder = (totalCells - pairsPerEmoji * emojis.length * 2) ~/ 2;

    final List<int> emojiIndices = [];
    for (int i = 0; i < emojis.length; i++) {
      final count = pairsPerEmoji + (i < remainder ? 1 : 0);
      for (int j = 0; j < count * 2; j++) {
        emojiIndices.add(i);
      }
    }

    // Fisher-Yates 洗牌
    final rng = Random();
    for (int i = emojiIndices.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final temp = emojiIndices[i];
      emojiIndices[i] = emojiIndices[j];
      emojiIndices[j] = temp;
    }

    // 构建网格
    grid = List.generate(config.rows, (r) => List.filled(config.cols, null));
    int idx = 0;
    int cellId = 0;
    for (int r = 0; r < config.rows; r++) {
      for (int c = 0; c < config.cols; c++) {
        final ei = emojiIndices[idx];
        grid[r][c] = Cell(
          id: cellId++,
          row: r,
          col: c,
          emoji: emojis[ei],
          ttsLabel: ttsLabels[ei],
        );
        idx++;
      }
    }

    notifyListeners();
  }

  /// 尝试匹配两个格子
  /// 成功消除 +10 分，返回 true；失败返回 false
  bool tryMatch(Cell start, Cell end) {
    // 必须是相同 emoji 且未消除
    if (start.emoji != end.emoji ||
        start.isEliminated ||
        end.isEliminated) {
      return false;
    }

    final path = PathFinder.findPath(start, end, grid);
    if (path == null) return false;

    // 保存路径用于可视化
    currentPath = path;

    // 消除两个格子
    grid[start.row][start.col] =
        grid[start.row][start.col]!.copyWith(isEliminated: true);
    grid[end.row][end.col] =
        grid[end.row][end.col]!.copyWith(isEliminated: true);

    score += 10;
    selectedCell = null;

    // 检查是否通关
    if (_checkAllCleared()) {
      score += 50;
      _isVictory = true;
    }

    notifyListeners();
    return true;
  }

  /// 查找提示：返回首个可配对的坐标 (row, col) 对，无解返回 null
  (int, int, int, int)? findHint() {
    final pairs = _findAllPairs();
    if (pairs.isEmpty) return null;
    final pair = pairs.first;
    return (pair.$1, pair.$2, pair.$3, pair.$4);
  }

  /// 手动提示：找到配对并扣分
  (int, int, int, int)? useHint() {
    final hint = findHint();
    if (hint != null) {
      score = max(0, score - 5);
      notifyListeners();
    }
    return hint;
  }

  /// 检查死局：遍历未消除同类格子，无解返回 true
  bool checkDeadlock() {
    final pairs = _findAllPairs();
    return pairs.isEmpty;
  }

  /// 洗牌剩余未消除的格子（Fisher-Yates）
  void shuffleRemaining() {
    final rng = Random();

    // 收集所有未消除的格子
    final remaining = <Cell>[];
    for (final row in grid) {
      for (final cell in row) {
        if (cell != null && !cell.isEliminated) {
          remaining.add(cell);
        }
      }
    }

    if (remaining.length < 2) return;

    // Fisher-Yates 洗牌
    for (int i = remaining.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      // 交换 emoji 和 ttsLabel
      final tempEmoji = remaining[i].emoji;
      final tempTts = remaining[i].ttsLabel;
      grid[remaining[i].row][remaining[i].col] = remaining[i].copyWith(
        emoji: remaining[j].emoji,
        ttsLabel: remaining[j].ttsLabel,
      );
      grid[remaining[j].row][remaining[j].col] = remaining[j].copyWith(
        emoji: tempEmoji,
        ttsLabel: tempTts,
      );
    }

    notifyListeners();
  }

  /// 选中格子
  /// 返回 true=匹配成功，false=匹配失败，null=仅选中/取消选中
  bool? selectCell(int row, int col) {
    if (!isPlaying) return null;
    final cell = grid[row][col];
    if (cell == null || cell.isEliminated) return null;

    if (selectedCell?.id == cell.id) {
      selectedCell = null;
      notifyListeners();
      return null; // 取消选中
    } else if (selectedCell != null) {
      final matched = tryMatch(selectedCell!, cell);
      if (!matched) {
        selectedCell = null;
        notifyListeners();
      }
      return matched; // 匹配结果
    } else {
      selectedCell = cell;
      notifyListeners();
      return null; // 首次选中
    }
  }

  /// 重置游戏
  void reset() {
    grid = [];
    score = 0;
    selectedCell = null;
    timeElapsed = 0;
    isPlaying = false;
    currentPath = null;
    _isVictory = false;
    notifyListeners();
  }

  /// 更新计时
  void tick() {
    if (isPlaying) {
      timeElapsed++;
      notifyListeners();
    }
  }

  // ---- 私有方法 ----

  /// 查找所有可配对的格子 (r1, c1, r2, c2)
  List<(int, int, int, int)> _findAllPairs() {
    final pairs = <(int, int, int, int)>[];
    final rows = grid.length;
    if (rows == 0) return pairs;
    final cols = grid[0].length;

    // 按 emoji 分组
    final groups = <String, List<Cell>>{};
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = grid[r][c];
        if (cell != null && !cell.isEliminated) {
          groups.putIfAbsent(cell.emoji, () => []).add(cell);
        }
      }
    }

    // 遍历每组，找可连通的配对
    for (final cells in groups.values) {
      for (int i = 0; i < cells.length; i++) {
        for (int j = i + 1; j < cells.length; j++) {
          final path = PathFinder.findPath(cells[i], cells[j], grid);
          if (path != null) {
            pairs.add((
              cells[i].row,
              cells[i].col,
              cells[j].row,
              cells[j].col,
            ));
          }
        }
      }
    }

    return pairs;
  }

  /// 检查是否全部消除
  bool _checkAllCleared() {
    for (final row in grid) {
      for (final cell in row) {
        if (cell != null && !cell.isEliminated) return false;
      }
    }
    return true;
  }
}
