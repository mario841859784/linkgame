import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cell.dart';
import '../models/emoji_themes.dart';
import '../services/game_state.dart';
import '../services/settings_service.dart';
import '../utils/app_lifecycle.dart';
import '../utils/audio_service.dart';
import '../utils/haptic_service.dart';
import '../utils/tts_service.dart';
import '../widgets/magnifier_widget.dart';
import 'victory_screen.dart';

/// 游戏对局页面
/// 使用 GestureDetector.onPan 管理手势生命周期
/// 集成放大镜、跨界震动、TTS 驻留播报、路径可视化
class PlaySessionScreen extends StatefulWidget {
  const PlaySessionScreen({super.key});

  @override
  State<PlaySessionScreen> createState() => _PlaySessionScreenState();
}

class _PlaySessionScreenState extends State<PlaySessionScreen>
    with SingleTickerProviderStateMixin {
  late final AppLifecycleObserver _lifecycleObserver;

  // 手势状态
  Cell? _startCell;
  int? _currentHoveredIndex;
  int? _lastHoveredIndex;
  bool _isDragging = false;
  Timer? _dwellTimer;
  Offset? _magnifierPosition;

  // 消除动画计时器
  Timer? _eliminationTimer;

  // 游戏时钟计时器
  Timer? _clockTimer;

  // 路径可视化
  List<Offset>? _matchPath;
  Timer? _pathClearTimer;

  // 消除动画 — 记录刚被消除的格子 ID
  final Set<int> _eliminatingIds = {};

  // 内部辅助
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();
  double _totalPanDistance = 0;

  // 得分变化动画
  int _displayScore = 0;
  int _prevScore = 0;
  Timer? _scoreAnimTimer;

  // 提示高亮
  (int, int, int, int)? _hintPair;
  Timer? _hintClearTimer;

  // 胜利弹窗防重复
  bool _victoryShown = false;

  // 常量
  static const double _panThreshold = 30.0;
  static const int _dwellMs = 200;

  @override
  void initState() {
    super.initState();

    _lifecycleObserver = AppLifecycleObserver(
      onPause: _handlePause,
      onResume: _handleResume,
    );
    _lifecycleObserver.init();

    TtsService.instance.init();

    // 从设置读取难度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = context.read<SettingsService>();
        // 同步服务状态
        TtsService.instance.enabled = settings.isTtsEnabled;
        HapticService.instance.enabled = settings.isVibrationEnabled;
        final gs = context.read<GameState>();
        gs.initializeGrid(settings.difficulty, EmojiTheme.random());
        _displayScore = gs.score;
        _prevScore = gs.score;
        _victoryShown = false;
        _startClockTimer();
      }
    });

    // 监听分数变化以触发动画
    context.read<GameState>().addListener(_onGameStateChange);
  }

  void _onGameStateChange() {
    if (!mounted) return;
    final gs = context.read<GameState>();
    if (gs.score != _displayScore) {
      setState(() {
        _prevScore = _displayScore;
        _displayScore = gs.score;
      });
      _scoreAnimTimer?.cancel();
      _scoreAnimTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _prevScore = _displayScore;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    context.read<GameState>().removeListener(_onGameStateChange);
    _dwellTimer?.cancel();
    _pathClearTimer?.cancel();
    _hintClearTimer?.cancel();
    _scoreAnimTimer?.cancel();
    _eliminationTimer?.cancel();
    _clockTimer?.cancel();
    _lifecycleObserver.dispose();
    TtsService.instance.dispose();
    super.dispose();
  }

  // ---- 生命周期回调 ----

  void _handlePause() {
    TtsService.instance.stop();
    _dwellTimer?.cancel();
    _clockTimer?.cancel();
  }

  void _handleResume() {
    _isDragging = false;
    _magnifierPosition = null;
    _startCell = null;
    _lastHoveredIndex = null;
    _victoryShown = false;
    _startClockTimer();
  }

  // ---- 时钟 ----

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        context.read<GameState>().tick();
      }
    });
  }

  void _showHint() {
    final gs = context.read<GameState>();
    final hint = gs.useHint();
    if (hint != null) {
      setState(() {
        _hintPair = hint;
      });
      _hintClearTimer?.cancel();
      _hintClearTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _hintPair = null;
          });
        }
      });
      TtsService.instance.speak('提示：找到相同的图案');
      AudioService.instance.play('hint');
    } else {
      // 无解，自动洗牌
      gs.shuffleRemaining();
      HapticService.instance.vibrateShuffle();
      TtsService.instance.speak('没有可消除的配对，自动重新排列');
    }
  }

  // ---- 格子定位 ----

  (int row, int col)? _findCellAtPosition(
    Offset localOffset,
    double cellSize,
    int rows,
    int cols,
    Offset gridOffset,
  ) {
    final adjustedX = localOffset.dx - gridOffset.dx - 8;
    final adjustedY = localOffset.dy - gridOffset.dy - 8;

    final col = (adjustedX / cellSize).floor();
    final row = (adjustedY / cellSize).floor();

    if (row < 0 || row >= rows || col < 0 || col >= cols) return null;
    return (row, col);
  }

  int _cellIndex(int row, int col, int cols) {
    return row * cols + col;
  }

  Cell? _getCellAtPosition(
    Offset localOffset,
    double cellSize,
    int rows,
    int cols,
    Offset gridOffset,
  ) {
    final pos = _findCellAtPosition(localOffset, cellSize, rows, cols, gridOffset);
    if (pos == null) return null;
    final gs = context.read<GameState>();
    return gs.grid[pos.$1][pos.$2];
  }

  // ---- 手势回调 ----

  void _onPanDown(DragDownDetails details, double cellSize, int rows, int cols, Offset gridOffset) {
    final renderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localOffset = renderBox.globalToLocal(details.globalPosition);
    final cell = _getCellAtPosition(localOffset, cellSize, rows, cols, gridOffset);

    _startCell = cell;
    _totalPanDistance = 0;
    _isDragging = true;
    _magnifierPosition = localOffset;
    _lastHoveredIndex = null;

    if (cell != null) {
      final settings = context.read<SettingsService>();
      if (settings.isVibrationEnabled) {
        HapticService.instance.vibrateSelect();
      }
      AudioService.instance.play('select');
    }
  }

  void _onPanUpdate(
    DragUpdateDetails details,
    double cellSize,
    int rows,
    int cols,
    Offset gridOffset,
  ) {
    final renderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localOffset = renderBox.globalToLocal(details.globalPosition);

    _totalPanDistance += details.delta.distance;

    // 放大镜实时更新
    _magnifierPosition = localOffset;

    final cell = _getCellAtPosition(localOffset, cellSize, rows, cols, gridOffset);
    if (cell == null) return;

    final currentIndex = _cellIndex(cell.row, cell.col, cols);

    // 跨界震动
    final settings = context.read<SettingsService>();
    if (_lastHoveredIndex != null && currentIndex != _lastHoveredIndex) {
      if (settings.isVibrationEnabled) {
        HapticService.instance.vibrateCrossBoundary();
      }
    }

    // TTS 驻留播报
    _dwellTimer?.cancel();
    if (settings.isTtsEnabled) {
      _dwellTimer = Timer(Duration(milliseconds: _dwellMs), () {
        if (mounted) {
          TtsService.instance.speak(cell.ttsLabel);
        }
      });
    }

    _lastHoveredIndex = currentIndex;
    _currentHoveredIndex = currentIndex;
  }

  void _onPanEnd(double cellSize, int rows, int cols) {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _magnifierPosition = null;
    _isDragging = false;

    final endCell = _currentHoveredIndex != null
        ? _getCellByIndex(_currentHoveredIndex!, cellSize, rows, cols)
        : _startCell;

    if (_totalPanDistance >= _panThreshold &&
        _startCell != null &&
        endCell != null &&
        _startCell!.id != endCell.id) {
      _tryMatchCells(_startCell!, endCell);
    } else if (_startCell != null) {
      final gs = context.read<GameState>();
      final settings = context.read<SettingsService>();
      final result = gs.selectCell(_startCell!.row, _startCell!.col);

      // 处理点击匹配结果
      if (result == true) {
        // 匹配成功
        if (settings.isVibrationEnabled) {
          HapticService.instance.vibrateSuccess();
        }
        AudioService.instance.play('eliminate');
        if (settings.isTtsEnabled) {
          TtsService.instance.speak('配对成功');
        }

        // 显示路径
        final path = gs.currentPath;
        if (path != null) {
          setState(() {
            _matchPath = path;
          });
          _pathClearTimer?.cancel();
          _pathClearTimer = Timer(
            const Duration(milliseconds: 600),
            () {
              if (mounted) {
                setState(() {
                  _matchPath = null;
                });
              }
            },
          );
        }

        // 检查是否通关
        if (gs.isVictory && !_victoryShown) {
          _victoryShown = true;
          _showVictory(gs.score);
        }
      } else if (result == false) {
        // 匹配失败
        if (settings.isVibrationEnabled) {
          HapticService.instance.vibrateFail();
        }
        AudioService.instance.play('fail');
      }
    }

    _startCell = null;
    _currentHoveredIndex = null;
    _lastHoveredIndex = null;
    _totalPanDistance = 0;
  }

  Cell? _getCellByIndex(int index, double cellSize, int rows, int cols) {
    final gs = context.read<GameState>();
    final row = index ~/ cols;
    final col = index % cols;
    if (row >= 0 && row < rows && col >= 0 && col < cols) {
      return gs.grid[row][col];
    }
    return null;
  }

  void _tryMatchCells(Cell start, Cell end) {
    final gs = context.read<GameState>();
    final settings = context.read<SettingsService>();
    final matched = gs.tryMatch(start, end);

    if (matched) {
      // 标记消除动画
      setState(() {
        _eliminatingIds.add(start.id);
        _eliminatingIds.add(end.id);
      });
      _eliminationTimer?.cancel();
      _eliminationTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _eliminatingIds.remove(start.id);
            _eliminatingIds.remove(end.id);
          });
        }
      });

      if (settings.isVibrationEnabled) {
        HapticService.instance.vibrateSuccess();
      }
      AudioService.instance.play('eliminate');
      if (settings.isTtsEnabled) {
        TtsService.instance.speak('配对成功');
      }

      // 显示路径
      final path = gs.currentPath;
      if (path != null) {
        setState(() {
          _matchPath = path;
        });
        _pathClearTimer?.cancel();
        _pathClearTimer = Timer(
          const Duration(milliseconds: 600),
          () {
            if (mounted) {
              setState(() {
                _matchPath = null;
              });
            }
          },
        );
      }

      // 检查是否通关
      if (gs.isVictory && !_victoryShown) {
        _victoryShown = true;
        _showVictory(gs.score);
      }
    } else {
      if (settings.isVibrationEnabled) {
        HapticService.instance.vibrateFail();
      }
      AudioService.instance.play('fail');
    }
  }

  void _showVictory(int score) {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => VictoryScreen(finalScore: score),
    ).then((playAgain) {
      if (!mounted) return;
      if (playAgain == true) {
        // 再来一局
        final settings = context.read<SettingsService>();
        final gs = context.read<GameState>();
        gs.clearVictory();
        gs.initializeGrid(settings.difficulty, EmojiTheme.random());
        _victoryShown = false;
      } else {
        // 返回主页
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  // ---- 路径绘制 ----

  Widget _buildPathOverlay(double cellSize, ColorScheme cs, Offset gridOffset) {
    if (_matchPath == null || _matchPath!.length < 2) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _PathPainter(
        path: _matchPath!,
        cellSize: cellSize,
        pathColor: cs.tertiary,
        gridOffset: gridOffset,
      ),
      size: Size.infinite,
    );
  }

  // ---- 计算剩余格子数 ----

  int _countRemaining(GameState gs) {
    int count = 0;
    for (final row in gs.grid) {
      for (final cell in row) {
        if (cell != null && !cell.isEliminated) {
          count++;
        }
      }
    }
    return count;
  }

  // ---- 格子 Widget ----

  Widget _buildCell({
    required Cell cell,
    required double cellSize,
    required bool isSelected,
    required bool isEliminating,
    required bool isHinted,
    required ColorScheme cs,
  }) {
    // 消除动画：缩放 + 淡出
    if (isEliminating) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 350),
        tween: Tween<double>(begin: 1.0, end: 0.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: _cellContainer(
          cell: cell,
          cellSize: cellSize,
          isSelected: false,
          isHinted: false,
          cs: cs,
        ),
      );
    }

    return _cellContainer(
      cell: cell,
      cellSize: cellSize,
      isSelected: isSelected,
      isHinted: isHinted,
      cs: cs,
    );
  }

  Widget _cellContainer({
    required Cell cell,
    required double cellSize,
    required bool isSelected,
    required bool isHinted,
    required ColorScheme cs,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isSelected
            ? cs.primary.withValues(alpha:0.12)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? cs.primary
              : isHinted
                  ? cs.secondary.withValues(alpha:0.8)
                  : cs.outlineVariant.withValues(alpha:0.3),
          width: isSelected ? 3.5 : isHinted ? 3 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha:0.25),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          cell.emoji,
          style: TextStyle(
            fontSize: cellSize * 0.55,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ---- UI 构建 ----

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
        title: Consumer<GameState>(
          builder: (context, gs, _) {
            // 得分变化动画
            final scoreChanged = _prevScore != _displayScore;
            return AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: ts.headlineMedium!.copyWith(
                color: scoreChanged ? cs.tertiary : cs.onSurface,
                fontSize: scoreChanged ? 32 : 28,
              ),
              child: Text('得分: $_displayScore'),
            );
          },
        ),
        actions: [
          Consumer<GameState>(
            builder: (context, gs, _) => Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '剩余: ${_countRemaining(gs)}',
                    style: ts.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gs = context.watch<GameState>();
          final rows = gs.grid.length;
          if (rows == 0) {
            return const Center(child: CircularProgressIndicator());
          }
          final cols = gs.grid[0].length;

          // 竖屏自适应：min(宽度/列, 高度/行)
          final availableHeight =
              constraints.maxHeight - 140; // 减去顶部和底部控件高度
          final cellSize = (constraints.maxWidth / cols)
              .clamp(40.0, availableHeight / rows);

          // 计算 GridView 在 Stack 中的偏移
          final gridRenderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
          final stackRenderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
          final gridOffset = (gridRenderBox != null && stackRenderBox != null)
              ? gridRenderBox.localToGlobal(Offset.zero) - stackRenderBox.localToGlobal(Offset.zero)
              : Offset.zero;

          return Column(
            children: [
              // 游戏棋盘区域
              Expanded(
                child: GestureDetector(
                  onPanDown: (details) =>
                      _onPanDown(details, cellSize, rows, cols, gridOffset),
                  onPanUpdate: (details) =>
                      _onPanUpdate(details, cellSize, rows, cols, gridOffset),
                  onPanEnd: (_) => _onPanEnd(cellSize, rows, cols),
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    key: _stackKey,
                    children: [
                      Center(
                        child: GridView.builder(
                          key: _gridKey,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            childAspectRatio: 1,
                          ),
                          itemCount: rows * cols,
                          itemBuilder: (context, index) {
                            final row = index ~/ cols;
                            final col = index % cols;
                            final cell = gs.grid[row][col];

                            if (cell == null || cell.isEliminated) {
                              return const SizedBox.shrink();
                            }

                            final isSelected = gs.selectedCell?.id == cell.id;
                            final isEliminating =
                                _eliminatingIds.contains(cell.id);

                            // 检查是否为提示高亮
                            var isHinted = false;
                            if (_hintPair != null) {
                              final hp = _hintPair!;
                              if ((row == hp.$1 && col == hp.$2) ||
                                  (row == hp.$3 && col == hp.$4)) {
                                isHinted = true;
                              }
                            }

                            return Semantics(
                              label: cell.ttsLabel,
                              hint: cell.isEliminated ? '已消除' : '未消除',
                              child: _buildCell(
                                cell: cell,
                                cellSize: cellSize,
                                isSelected: isSelected,
                                isEliminating: isEliminating,
                                isHinted: isHinted,
                                cs: cs,
                              ),
                            );
                          },
                        ),
                      ),
                      // 路径连线可视化
                      if (_matchPath != null)
                        _buildPathOverlay(cellSize, cs, gridOffset),
                      // 放大镜
                      if (_isDragging &&
                          _magnifierPosition != null &&
                          _currentHoveredIndex != null)
                        MagnifierWidget(
                          emoji: _getCellByIndex(
                                  _currentHoveredIndex!,
                                  cellSize,
                                  rows,
                                  cols,
                                )
                                ?.emoji ??
                              '',
                          position: _magnifierPosition!,
                          cellSize: cellSize,
                        ),
                    ],
                  ),
                ),
              ),

              // 底部操作栏
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      // 提示按钮
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _showHint,
                          icon: const Icon(Icons.lightbulb, size: 32),
                          label: Text(
                            '提示 (-5)',
                            style: ts.labelLarge,
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(64),
                            backgroundColor: cs.secondary,
                            foregroundColor: cs.onSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 返回按钮
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.home_rounded, size: 32),
                          label: Text(
                            '返回',
                            style: ts.labelLarge?.copyWith(
                              color: cs.primary,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(64),
                            side: BorderSide(color: cs.primary, width: 2.5),
                            foregroundColor: cs.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 路径连线绘制器 — 加粗圆角线条 + 发光效果
class _PathPainter extends CustomPainter {
  final List<Offset> path;
  final double cellSize;
  final Color pathColor;
  final Offset gridOffset;

  _PathPainter({
    required this.path,
    required this.cellSize,
    required this.pathColor,
    required this.gridOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    // 发光层
    final glowPaint = Paint()
      ..color = pathColor.withValues(alpha:0.3)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..filterQuality = FilterQuality.high;

    // 主线
    final paint = Paint()
      ..color = pathColor
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pathObj = Path();
    for (int i = 0; i < path.length; i++) {
      final point = path[i];
      // 将 (row, col) 转换为像素坐标
      final dx = point.dy * cellSize + cellSize / 2 + gridOffset.dx;
      final dy = point.dx * cellSize + cellSize / 2 + gridOffset.dy;
      if (i == 0) {
        pathObj.moveTo(dx, dy);
      } else {
        pathObj.lineTo(dx, dy);
      }
    }

    canvas.drawPath(pathObj, glowPaint);
    canvas.drawPath(pathObj, paint);

    // 起点标记
    final startPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.fill;
    final start = path.first;
    canvas.drawCircle(
      Offset(
        start.dy * cellSize + cellSize / 2 + gridOffset.dx,
        start.dx * cellSize + cellSize / 2 + gridOffset.dy,
      ),
      8,
      startPaint,
    );

    // 终点标记
    final end = path.last;
    canvas.drawCircle(
      Offset(
        end.dy * cellSize + cellSize / 2 + gridOffset.dx,
        end.dx * cellSize + cellSize / 2 + gridOffset.dy,
      ),
      8,
      startPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.cellSize != cellSize || oldDelegate.gridOffset != gridOffset;
  }
}
