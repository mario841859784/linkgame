import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/cell.dart';
import '../models/emoji_themes.dart';
import '../services/content_service.dart';
import '../services/game_state.dart';
import '../services/path_finder.dart';
import '../services/settings_service.dart';
import '../utils/app_lifecycle.dart';
import '../utils/audio_service.dart';
import '../utils/haptic_service.dart';
import '../utils/tts_service.dart';
import '../style/palette.dart';
import '../widgets/juice_painter.dart';
import '../widgets/live_link_painter.dart';
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
  Timer? _dwellTimer;

  // 放大镜状态：(手指位置, 当前悬浮格子的 emoji)；null = 隐藏
  // 用 ValueNotifier 驱动独立图层，避免 pan 事件触发整页重建
  final ValueNotifier<(Offset, String)?> _magnifier = ValueNotifier(null);

  // 实时连接线（拖动中）：(像素路径点, 是否可消除)；null = 隐藏
  final ValueNotifier<(List<Offset>, bool)?> _liveLink = ValueNotifier(null);

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

  // ---- 爽点层 ----
  // 消除爆点粒子 + 跳分（Ticker 驱动物理，ValueNotifier 只重绘本层）
  final List<JuiceParticle> _juiceParticles = [];
  final List<ScoreFloat> _juiceFloats = [];
  final ValueNotifier<JuiceFrame> _juice =
      ValueNotifier(const JuiceFrame(particles: [], floats: []));
  Ticker? _juiceTicker;
  Duration? _juiceLast;

  // 连击弹字：(连击数, 序号)；序号自增驱动弹字动画重启
  final ValueNotifier<(int, int)?> _comboPop = ValueNotifier(null);
  int _comboSeq = 0;

  // 本局失误数（零失误通关判定）与总对数（里程碑判定）
  int _mismatchCount = 0;
  int _totalPairs = 0;

  // 庆祝粒子配色（与胜利彩纸同款暖色）
  static const _juiceColors = [
    Color(0xFFFFD700), Color(0xFFFF6B35), Color(0xFFFF4757),
    Color(0xFF2ED573), Color(0xFF1E90FF), Color(0xFFFFA502),
  ];

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

    // 从设置读取难度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = context.read<SettingsService>();
        // 同步服务状态（TTS 引擎在 main 启动时已初始化，这里只同步开关与语速）
        TtsService.instance.enabled = settings.isTtsEnabled;
        TtsService.instance.setRate(settings.ttsRate);
        HapticService.instance.enabled = settings.isVibrationEnabled;
        final gs = context.read<GameState>();
        gs.initializeGrid(settings.difficulty, EmojiTheme.random());
        _displayScore = gs.score;
        _prevScore = gs.score;
        _victoryShown = false;
        _mismatchCount = 0;
        _totalPairs = gs.grid.length * gs.grid[0].length ~/ 2;
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
    _magnifier.dispose();
    _liveLink.dispose();
    _juiceTicker?.dispose();
    _juice.dispose();
    _comboPop.dispose();
    super.dispose();
  }

  // ---- 生命周期回调 ----

  void _handlePause() {
    TtsService.instance.stop();
    _dwellTimer?.cancel();
    _clockTimer?.cancel();
  }

  void _handleResume() {
    _magnifier.value = null;
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
      TtsService.instance.speak(ContentService.instance.hintMessage);
      AudioService.instance.play('hint');
    } else {
      // 无解，自动洗牌
      gs.shuffleRemaining();
      HapticService.instance.vibrateShuffle();
      TtsService.instance.speak(ContentService.instance.noPairMessage);
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

  /// 格子（含棋盘外延 -1/cols 的虚拟行）中心点在 Stack 坐标系下的像素位置
  Offset _cellCenter(double row, double col, double tileSize, Offset gridOffset) {
    return Offset(
      gridOffset.dx + 8 + col * tileSize + tileSize / 2,
      gridOffset.dy + 8 + row * tileSize + tileSize / 2,
    );
  }

  // ---- 手势回调 ----

  void _onPanDown(DragDownDetails details, double tileSize, int rows, int cols, Offset gridOffset) {
    final renderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localOffset = renderBox.globalToLocal(details.globalPosition);
    final cell = _getCellAtPosition(localOffset, tileSize, rows, cols, gridOffset);

    _startCell = cell;
    _totalPanDistance = 0;
    _magnifier.value = (localOffset, (cell != null && !cell.isEliminated) ? cell.emoji : '');
    _liveLink.value = null;
    _lastHoveredIndex = null;

    // 只有按在未消除的格子上才给"选中"提示音与震动（已消除格子是 no-op）
    if (cell != null && !cell.isEliminated) {
      final settings = context.read<SettingsService>();
      if (settings.isVibrationEnabled) {
        HapticService.instance.vibrateSelect();
      }
      AudioService.instance.play('select');
    }
  }

  void _onPanUpdate(
    DragUpdateDetails details,
    double tileSize,
    int rows,
    int cols,
    Offset gridOffset,
  ) {
    final renderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localOffset = renderBox.globalToLocal(details.globalPosition);

    _totalPanDistance += details.delta.distance;

    final gs = context.read<GameState>();
    final cell = _getCellAtPosition(localOffset, tileSize, rows, cols, gridOffset);

    // 放大镜实时更新（ValueNotifier 直推，不触发整页重建）
    _magnifier.value =
        (localOffset, (cell != null && !cell.isEliminated) ? cell.emoji : '');

    // 实时连接线：起点 → 当前悬浮格（可消除=金色实线 / 不能消除=红色虚线）
    if (cell != null &&
        !cell.isEliminated &&
        _startCell != null &&
        _startCell!.id != cell.id) {
      final route = PathFinder.findPath(_startCell!, cell, gs.grid);
      if (route != null) {
        _liveLink.value = (
          [
            for (final p in route)
              _cellCenter(p.dx, p.dy, tileSize, gridOffset),
          ],
          true,
        );
      } else {
        _liveLink.value = ([
          _cellCenter(
              _startCell!.row.toDouble(), _startCell!.col.toDouble(), tileSize, gridOffset),
          _cellCenter(cell.row.toDouble(), cell.col.toDouble(), tileSize, gridOffset),
        ], false);
      }
    } else {
      _liveLink.value = null;
    }

    if (cell == null) return;

    final currentIndex = _cellIndex(cell.row, cell.col, cols);

    // 跨界震动
    final settings = context.read<SettingsService>();
    if (_lastHoveredIndex != null && currentIndex != _lastHoveredIndex) {
      if (settings.isVibrationEnabled) {
        HapticService.instance.vibrateCrossBoundary();
      }
    }

    // TTS 驻留播报：仅跨入新格子时重新武装计时器，长按同格不重复播报
    if (currentIndex != _lastHoveredIndex) {
      _dwellTimer?.cancel();
      if (settings.isTtsEnabled && !cell.isEliminated) {
        _dwellTimer = Timer(Duration(milliseconds: _dwellMs), () {
          if (mounted) {
            TtsService.instance.speak(cell.ttsLabel);
          }
        });
      }
    }

    _lastHoveredIndex = currentIndex;
    _currentHoveredIndex = currentIndex;
  }

  void _onPanEnd(double tileSize, int rows, int cols, Offset gridOffset) {
    _dwellTimer?.cancel();
    _dwellTimer = null;
    _magnifier.value = null;
    _liveLink.value = null;

    final endCell = _currentHoveredIndex != null
        ? _getCellByIndex(_currentHoveredIndex!, tileSize, rows, cols)
        : _startCell;

    if (_totalPanDistance >= _panThreshold &&
        _startCell != null &&
        endCell != null &&
        _startCell!.id != endCell.id) {
      _tryMatchCells(_startCell!, endCell, tileSize, gridOffset);
    } else if (_startCell != null) {
      final gs = context.read<GameState>();
      final settings = context.read<SettingsService>();
      final result = gs.selectCell(_startCell!.row, _startCell!.col);

      // 处理点击匹配结果
      if (result == true) {
        // 匹配成功
        _celebrateElimination(_startCell!, endCell!, tileSize, gridOffset);

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
        _mismatchCount++;
        if (settings.isVibrationEnabled) {
          HapticService.instance.vibrateFail();
        }
        AudioService.instance.play('fail');
      } else if (gs.selectedCell != null &&
          gs.selectedCell!.id == _startCell!.id &&
          settings.isTtsEnabled) {
        // 首次选中：快速点按时驻留播报（200ms）来不及触发就被 onPanEnd 取消，
        // 这里显式播报被选中格子的名称；慢速长按时驻留已播报过，会被节流跳过。
        // 必须校验"点的就是被选中的那块"：点已消除格子是 no-op，不能重复播报原选中块
        TtsService.instance.speak(gs.selectedCell!.ttsLabel);
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

  void _tryMatchCells(
    Cell start,
    Cell end,
    double tileSize,
    Offset gridOffset,
  ) {
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

      _celebrateElimination(start, end, tileSize, gridOffset);

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
      _mismatchCount++;
      if (settings.isVibrationEnabled) {
        HapticService.instance.vibrateFail();
      }
      AudioService.instance.play('fail');
    }
  }

  // ---- 消除庆祝（爽点漏斗）：震动/音效/粒子/跳分/连击弹字/里程碑播报 ----

  void _celebrateElimination(
    Cell a,
    Cell b,
    double tileSize,
    Offset gridOffset,
  ) {
    final gs = context.read<GameState>();
    final settings = context.read<SettingsService>();
    if (settings.isVibrationEnabled) {
      HapticService.instance.vibrateSuccess();
    }
    AudioService.instance.play('eliminate');
    _spawnJuice(a, b, tileSize, gridOffset);

    final combo = gs.streak;
    if (combo >= 2) {
      _comboSeq++;
      _comboPop.value = (combo, _comboSeq);
    }
    if (settings.isTtsEnabled) {
      final remainingPairs = _countRemaining(gs) ~/ 2;
      TtsService.instance.speak(_eliminateLine(remainingPairs, combo));
    }
  }

  /// 每消一对只说一句话，优先级：里程碑 > 连击 > 随机表扬
  String _eliminateLine(int remainingPairs, int combo) {
    if (remainingPairs == 1) return '最后一对，冲刺！';
    if (remainingPairs == 5) return '还剩五对！';
    if (_totalPairs > 0 && remainingPairs == _totalPairs ~/ 2) return '过半啦！';
    if (combo >= 2) return _comboLine(combo);
    return TtsService.randomPraise();
  }

  String _comboLine(int n) {
    const cn = ['', '', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (n < cn.length) return '${cn[n]}连消！';
    return '$n 连消，太惊人了！';
  }

  void _spawnJuice(Cell a, Cell b, double tileSize, Offset gridOffset) {
    final cs = Theme.of(context).colorScheme;
    final rng = math.Random();
    final centerA =
        _cellCenter(a.row.toDouble(), a.col.toDouble(), tileSize, gridOffset);
    final centerB =
        _cellCenter(b.row.toDouble(), b.col.toDouble(), tileSize, gridOffset);
    for (final center in [centerA, centerB]) {
      for (int i = 0; i < 14; i++) {
        final angle = rng.nextDouble() * math.pi * 2;
        final speed = 130.0 + rng.nextDouble() * 260.0;
        _juiceParticles.add(JuiceParticle(
          pos: center,
          vel: Offset(math.cos(angle) * speed, math.sin(angle) * speed - 190),
          color: _juiceColors[rng.nextInt(_juiceColors.length)],
          size: 4 + rng.nextDouble() * 4,
          round: rng.nextBool(),
          maxLife: 0.55 + rng.nextDouble() * 0.35,
        ));
      }
    }
    _juiceFloats.add(ScoreFloat(
      origin: Offset((centerA.dx + centerB.dx) / 2,
          (centerA.dy + centerB.dy) / 2 - tileSize / 3),
      text: '+10',
      color: cs.secondary,
    ));
    _startJuiceTicker();
  }

  void _startJuiceTicker() {
    _juiceTicker ??= createTicker(_onJuiceTick);
    if (!_juiceTicker!.isActive) {
      _juiceLast = null;
      _juiceTicker!.start();
    }
  }

  void _onJuiceTick(Duration elapsed) {
    final last = _juiceLast;
    final dt = last == null ? 0.0 : (elapsed - last).inMicroseconds / 1e6;
    _juiceLast = elapsed;
    if (dt <= 0) return;

    const gravity = 1500.0;
    _juiceParticles.removeWhere((p) {
      p.pos += p.vel * dt;
      p.vel = Offset(p.vel.dx, p.vel.dy + gravity * dt);
      p.angle += p.spin * dt;
      p.life -= dt;
      return p.life <= 0;
    });
    _juiceFloats.removeWhere((f) {
      f.age += dt;
      return f.age >= f.maxAge;
    });
    if (_juiceParticles.isEmpty && _juiceFloats.isEmpty) {
      _juiceTicker!.stop();
      _juiceLast = null;
    }
    _juice.value = JuiceFrame(
      particles: List.of(_juiceParticles),
      floats: List.of(_juiceFloats),
    );
  }

  Future<void> _showVictory(int score) async {
    final gs = context.read<GameState>();
    final settings = context.read<SettingsService>();
    final elapsed = gs.timeElapsed;
    final zeroMiss = _mismatchCount == 0;

    // 最快纪录（按难度持久化）
    int? best;
    bool newBest = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'best_seconds_${gs.difficulty}';
      final current = prefs.getInt(key);
      if (elapsed > 0 && (current == null || elapsed < current)) {
        newBest = current != null;
        best = elapsed;
        await prefs.setInt(key, elapsed);
      } else {
        best = current;
      }
    } catch (_) {}

    if (settings.isTtsEnabled) {
      final line = StringBuffer('恭喜通关！');
      if (zeroMiss) line.write('零失误，');
      if (newBest) line.write('刷新最快纪录！');
      TtsService.instance.speak(line.toString());
    }
    if (!mounted) return;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => VictoryScreen(
        finalScore: score,
        timeElapsed: elapsed,
        zeroMiss: zeroMiss,
        bestSeconds: best,
        newBest: newBest,
      ),
    ).then((playAgain) {
      if (!mounted) return;
      if (playAgain == true) {
        // 再来一局
        final settings = context.read<SettingsService>();
        final gs = context.read<GameState>();
        gs.clearVictory();
        gs.initializeGrid(settings.difficulty, EmojiTheme.random());
        _victoryShown = false;
        _mismatchCount = 0;
        _totalPairs = gs.grid.length * gs.grid[0].length ~/ 2;
      } else {
        // 返回主页
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  // ---- 路径绘制 ----

  Widget _buildPathOverlay(double tileSize, ColorScheme cs, Offset gridOffset) {
    if (_matchPath == null || _matchPath!.length < 2) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      painter: _PathPainter(
        path: _matchPath!,
        tileSize: tileSize,
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
            // 得分变化动画（藏蓝顶栏上必须用白字，得分跳动用琥珀色强调）
            final scoreChanged = _prevScore != _displayScore;
            return AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: ts.headlineMedium!.copyWith(
                color: scoreChanged ? Palette.amber : Colors.white,
                fontSize: scoreChanged ? 32 : 28,
              ),
              child: Text('得分: $_displayScore'),
            );
          },
        ),
        // 消除进度条：越接近通关越有盼头
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(5),
          child: Consumer<GameState>(
            builder: (context, gs, _) {
              final total = gs.grid.isEmpty || gs.grid[0].isEmpty
                  ? 0
                  : gs.grid.length * gs.grid[0].length ~/ 2;
              final remaining = _countRemaining(gs) ~/ 2;
              return LinearProgressIndicator(
                value: total == 0 ? null : (total - remaining) / total,
                minHeight: 5,
              );
            },
          ),
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
                      color: Colors.white,
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

          // 计算 GridView 在 Stack 中的偏移与真实格子宽度（GridView 有 8px 内边距）
          final gridRenderBox = _gridKey.currentContext?.findRenderObject() as RenderBox?;
          final stackRenderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
          final gridOffset = (gridRenderBox != null && stackRenderBox != null)
              ? gridRenderBox.localToGlobal(Offset.zero) - stackRenderBox.localToGlobal(Offset.zero)
              : Offset.zero;
          final tileSize = (gridRenderBox != null && gridRenderBox.size.width > 16)
              ? (gridRenderBox.size.width - 16) / cols
              : cellSize.toDouble();

          return Column(
            children: [
              // 游戏棋盘区域
              Expanded(
                child: GestureDetector(
                  onPanDown: (details) =>
                      _onPanDown(details, tileSize, rows, cols, gridOffset),
                  onPanUpdate: (details) =>
                      _onPanUpdate(details, tileSize, rows, cols, gridOffset),
                  onPanEnd: (_) => _onPanEnd(tileSize, rows, cols, gridOffset),
                  behavior: HitTestBehavior.translucent,
                  child: Stack(
                    key: _stackKey,
                    clipBehavior: Clip.none,
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
                        _buildPathOverlay(tileSize, cs, gridOffset),
                      // 实时连接线（拖动中）：金实线=可消除，红虚线=不能消除
                      ValueListenableBuilder<(List<Offset>, bool)?>(
                        valueListenable: _liveLink,
                        builder: (context, state, _) {
                          if (state == null) {
                            return const SizedBox.shrink();
                          }
                          return Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: LiveLinkPainter(
                                  points: state.$1,
                                  matchable: state.$2,
                                  validColor: cs.secondary,
                                  invalidColor: cs.error,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // 爽点层：消除爆点粒子 + 跳分（Ticker 物理驱动）
                      ValueListenableBuilder<JuiceFrame>(
                        valueListenable: _juice,
                        builder: (context, frame, _) {
                          if (frame.particles.isEmpty && frame.floats.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(painter: JuicePainter(frame: frame)),
                            ),
                          );
                        },
                      ),
                      // 连击弹字：×2 起中央上方弹出，数字越大越醒目
                      ValueListenableBuilder<(int, int)?>(
                        valueListenable: _comboPop,
                        builder: (context, state, _) {
                          if (state == null) return const SizedBox.shrink();
                          return Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: IgnorePointer(
                              child: Center(
                                child: TweenAnimationBuilder<double>(
                                  key: ValueKey(state.$2),
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 900),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, t, child) {
                                    final popIn =
                                        Curves.easeOutBack
                                            .transform((t * 4).clamp(0.0, 1.0));
                                    final fadeOut =
                                        t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
                                    return Opacity(
                                      opacity: fadeOut.clamp(0.0, 1.0),
                                      child: Transform.scale(
                                        scale: popIn,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '连击 ×${state.$1}',
                                    style: TextStyle(
                                      fontSize:
                                          30 + (state.$1.clamp(2, 8) - 2) * 2.0,
                                      fontWeight: FontWeight.w900,
                                      color: Palette.amberText,
                                      shadows: [
                                        // 白色光晕衬托，保证浅色棋盘上的可读性
                                        Shadow(
                                          color: Colors.white,
                                          blurRadius: 10,
                                        ),
                                        Shadow(
                                          color: Colors.white,
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      // 放大镜 — 独立重绘图层：
                      // ValueListenableBuilder 只重建本节点，RepaintBoundary 隔离重绘，
                      // Transform.translate 在绘制期偏移（无重布局），拖动全程 60fps 跟手
                      ValueListenableBuilder<(Offset, String)?>(
                        valueListenable: _magnifier,
                        builder: (context, state, _) {
                          if (state == null || state.$2.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final d = cellSize * 1.5;
                          // 顶行翻转：常规在手指上方 80dp，越界时翻到手指下方，
                          // 避免被标题栏区域裁掉；水平方向收进 Stack 边界内
                          final aboveTop = state.$1.dy - 80 - d / 2;
                          final centerY =
                              aboveTop < 0 ? state.$1.dy + 80 : state.$1.dy - 80;
                          final lo = d / 2 + 4;
                          final hi = constraints.maxWidth - d / 2 - 4;
                          final centerX =
                              state.$1.dx.clamp(lo, hi < lo ? lo : hi);
                          return Positioned(
                            left: 0,
                            top: 0,
                            child: RepaintBoundary(
                              child: Transform.translate(
                                offset: Offset(centerX - d / 2, centerY - d / 2),
                                child: MagnifierWidget(
                                  emoji: state.$2,
                                  cellSize: cellSize,
                                ),
                              ),
                            ),
                          );
                        },
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
  final double tileSize;
  final Color pathColor;
  final Offset gridOffset;

  _PathPainter({
    required this.path,
    required this.tileSize,
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
      // 将 (row, col) 转换为像素坐标（含 GridView 的 8px 内边距）
      final dx = gridOffset.dx + 8 + point.dy * tileSize + tileSize / 2;
      final dy = gridOffset.dy + 8 + point.dx * tileSize + tileSize / 2;
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
        gridOffset.dx + 8 + start.dy * tileSize + tileSize / 2,
        gridOffset.dy + 8 + start.dx * tileSize + tileSize / 2,
      ),
      8,
      startPaint,
    );

    // 终点标记
    final end = path.last;
    canvas.drawCircle(
      Offset(
        gridOffset.dx + 8 + end.dy * tileSize + tileSize / 2,
        gridOffset.dy + 8 + end.dx * tileSize + tileSize / 2,
      ),
      8,
      startPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.tileSize != tileSize || oldDelegate.gridOffset != gridOffset;
  }
}
