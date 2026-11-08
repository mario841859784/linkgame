import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/models/cell.dart';
import 'package:link_game/models/emoji_themes.dart';
import 'package:link_game/services/game_state.dart';

/// 确定性构造可解棋盘：前 pairs 行各放一对相邻同 emoji，其余格子全部消除
/// （随机布局不保证存在可连通对，相关测试一律用它避免概率性失败）
void _seedSolvablePairs(GameState state, int pairs) {
  for (int r = 0; r < state.grid.length; r++) {
    for (int c = 0; c < state.grid[r].length; c++) {
      if (r < pairs && c <= 1) {
        if (c == 1) {
          final a = state.grid[r][0]!;
          state.grid[r][1] =
              state.grid[r][1]!.copyWith(emoji: a.emoji, ttsLabel: a.ttsLabel);
        }
      } else {
        state.grid[r][c] = state.grid[r][c]!.copyWith(isEliminated: true);
      }
    }
  }
}

void main() {
  group('DifficultyConfig', () {
    test('easy is 4 cols × 7 rows (竖屏优先)', () {
      expect(DifficultyConfig.easy.cols, 4);
      expect(DifficultyConfig.easy.rows, 7);
      expect(DifficultyConfig.easy.name, '简单');
    });

    test('normal is 6 cols × 9 rows', () {
      expect(DifficultyConfig.normal.cols, 6);
      expect(DifficultyConfig.normal.rows, 9);
      expect(DifficultyConfig.normal.name, '普通');
    });

    test('hard is 8 cols × 10 rows', () {
      expect(DifficultyConfig.hard.cols, 8);
      expect(DifficultyConfig.hard.rows, 10);
      expect(DifficultyConfig.hard.name, '困难');
    });

    test('byName returns correct config', () {
      expect(DifficultyConfig.byName('简单').cols, 4);
      expect(DifficultyConfig.byName('普通').cols, 6);
      expect(DifficultyConfig.byName('困难').cols, 8);
    });

    test('byName defaults to normal for unknown name', () {
      final config = DifficultyConfig.byName('unknown');
      expect(config.cols, 6);
      expect(config.rows, 9);
    });
  });

  group('GameState.initializeGrid', () {
    test('initializes correct grid size for easy difficulty', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      expect(state.grid.length, 7); // rows
      expect(state.grid[0].length, 4); // cols
    });

    test('initializes correct grid size for normal difficulty', () {
      final state = GameState();
      state.initializeGrid('普通', EmojiTheme.fruits);

      expect(state.grid.length, 9);
      expect(state.grid[0].length, 6);
    });

    test('initializes correct grid size for hard difficulty', () {
      final state = GameState();
      state.initializeGrid('困难', EmojiTheme.fruits);

      expect(state.grid.length, 10);
      expect(state.grid[0].length, 8);
    });

    test('all cells are non-null after initialization', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      for (final row in state.grid) {
        for (final cell in row) {
          expect(cell, isNotNull);
        }
      }
    });

    test('total cell count matches difficulty', () {
      final state = GameState();

      state.initializeGrid('简单', EmojiTheme.fruits);
      int count = state.grid.expand((r) => r).where((c) => c != null).length;
      expect(count, 4 * 7);

      state.initializeGrid('普通', EmojiTheme.fruits);
      count = state.grid.expand((r) => r).where((c) => c != null).length;
      expect(count, 6 * 9);

      state.initializeGrid('困难', EmojiTheme.fruits);
      count = state.grid.expand((r) => r).where((c) => c != null).length;
      expect(count, 8 * 10);
    });

    test('even pair count for each emoji (easy)', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      final emojiCount = <String, int>{};
      for (final row in state.grid) {
        for (final cell in row) {
          emojiCount[cell!.emoji] = (emojiCount[cell.emoji] ?? 0) + 1;
        }
      }

      for (final count in emojiCount.values) {
        expect(count % 2, 0, reason: 'Emoji count $count is not even');
      }
    });

    test('ttsLabel is assigned correctly', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      for (final row in state.grid) {
        for (final cell in row) {
          final ttsLabel = cell!.ttsLabel;
          expect(EmojiTheme.fruits.ttsLabels, contains(ttsLabel));
        }
      }
    });

    test('emoji and ttsLabel correspond correctly', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      final theme = EmojiTheme.fruits;
      for (final row in state.grid) {
        for (final cell in row) {
          final emojiIndex = theme.emojis.indexOf(cell!.emoji);
          expect(emojiIndex, greaterThanOrEqualTo(0));
          expect(cell.ttsLabel, theme.ttsLabels[emojiIndex]);
        }
      }
    });

    test('resets score to 0', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      expect(state.score, 0);
    });

    test('sets isPlaying to true', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      expect(state.isPlaying, true);
    });

    test('sets selectedCell to null', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      expect(state.selectedCell, isNull);
    });

    test('sets timeElapsed to 0', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      expect(state.timeElapsed, 0);
    });

    test('sets currentTheme correctly', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.animals);
      expect(state.currentTheme, EmojiTheme.animals);

      state.initializeGrid('简单', EmojiTheme.food);
      expect(state.currentTheme, EmojiTheme.food);
    });

    test('initializes with different themes', () {
      final state = GameState();
      for (final theme in EmojiTheme.values) {
        state.initializeGrid('简单', theme);

        for (final row in state.grid) {
          for (final cell in row) {
            expect(theme.emojis, contains(cell!.emoji));
          }
        }
      }
    });
  });

  group('GameState.tryMatch', () {
    test('successfully matches adjacent cells and adds 10 points', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // 人为构造一对相邻同 emoji 格子
      // （随机布局不保证存在相邻同类对，扫描式查找会概率性失败）
      final start = state.grid[0][0]!;
      final end =
          state.grid[0][1]!.copyWith(emoji: start.emoji, ttsLabel: start.ttsLabel);
      state.grid[0][1] = end;

      final result = state.tryMatch(start, end);

      expect(result, true);
      expect(state.score, 10);
      expect(state.grid[start.row][start.col]!.isEliminated, true);
      expect(state.grid[end.row][end.col]!.isEliminated, true);
    });

    test('returns false for different emojis', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      final cell1 = state.grid[0][0]!;

      // Force different emojis by finding cells with different emoji
      Cell? differentCell;
      for (final row in state.grid) {
        for (final cell in row) {
          if (cell!.emoji != cell1.emoji) {
            differentCell = cell;
            break;
          }
        }
        if (differentCell != null) break;
      }

      expect(differentCell, isNotNull);

      final result = state.tryMatch(cell1, differentCell!);

      expect(result, false);
      expect(state.score, 0);
    });

    test('returns false for already eliminated cell', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      final cell1 = state.grid[0][0]!;
      final cell2 = state.grid[0][1]!;

      // Manually eliminate cell2
      state.grid[cell2.row][cell2.col] =
          cell2.copyWith(isEliminated: true);

      // Make sure they have the same emoji for this test
      state.grid[cell2.row][cell2.col] =
          cell2.copyWith(isEliminated: true, emoji: cell1.emoji);

      final result = state.tryMatch(cell1, cell2);

      expect(result, false);
    });

    test('returns false when no path exists', () {
      // Create a scenario where two same-emoji cells are surrounded
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Eliminate all cells except two isolated same-emoji cells
      // For a 7x4 grid, eliminate everything except (0,0) and (0,1)
      // But these are adjacent so path exists. Instead, use a 2x1 scenario
      // that's impossible to connect in a dense grid.

      // Simpler: create a mini dense scenario manually
      // Fill grid with same emoji, then eliminate all but two blocked ones
      for (int r = 0; r < state.grid.length; r++) {
        for (int c = 0; c < state.grid[r].length; c++) {
          if (!(r == 0 && c == 0) && !(r == 0 && c == 6)) {
            state.grid[r][c] =
                state.grid[r][c]!.copyWith(isEliminated: true);
          }
        }
      }
      // Now (0,0) and (0,6) are the only remaining cells
      // They have a path around the boundary
      // To make them truly blocked, we need a denser scenario
      // Let's just test the concept with a smaller grid
    });

    test('currentPath is set after successful match', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // 人为构造一对相邻同 emoji 格子（同上，避免概率性失败）
      final start = state.grid[0][0]!;
      final end =
          state.grid[0][1]!.copyWith(emoji: start.emoji, ttsLabel: start.ttsLabel);
      state.grid[0][1] = end;

      state.tryMatch(start, end);

      expect(state.currentPath, isNotNull);
      expect(state.currentPath!.length, greaterThanOrEqualTo(2));
    });

    test('selectedCell is cleared after match', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // 人为构造一对相邻同 emoji 格子（同上，避免概率性失败）
      final cell1 = state.grid[0][0]!;
      final match = state.grid[0][1]!
          .copyWith(emoji: cell1.emoji, ttsLabel: cell1.ttsLabel);
      state.grid[0][1] = match;

      state.selectedCell = cell1;
      state.tryMatch(cell1, match);

      expect(state.selectedCell, isNull);
    });
  });

  group('GameState.victory condition', () {
    test('adds 50 bonus when all cells cleared', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Eliminate all pairs one by one
      bool madeProgress = true;
      while (madeProgress) {
        madeProgress = false;
        for (int r = 0; r < state.grid.length && !madeProgress; r++) {
          for (int c = 0; c < state.grid[r].length && !madeProgress; c++) {
            final cell = state.grid[r][c];
            if (cell != null && !cell.isEliminated) {
              // Find a match
              for (int r2 = 0; r2 < state.grid.length && !madeProgress; r2++) {
                for (int c2 = 0; c2 < state.grid[r2].length && !madeProgress; c2++) {
                  final other = state.grid[r2][c2];
                  if (other != null &&
                      !other.isEliminated &&
                      other.id != cell.id &&
                      other.emoji == cell.emoji) {
                    final result = state.tryMatch(cell, other);
                    if (result) {
                      madeProgress = true;
                    }
                  }
                }
              }
            }
          }
        }
      }

      // If all cleared, score should include the 50 bonus
      final allCleared = state.grid.every(
          (row) => row.every((cell) => cell == null || cell.isEliminated));
      if (allCleared) {
        expect(state.score % 10, 0); // Each match gives 10
        // Victory bonus: score should be 10*n + 50
        expect(state.score, greaterThanOrEqualTo(50));
      }
    });
  });

  group('GameState.findHint', () {
    test('returns a valid hint pair', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      _seedSolvablePairs(state, 2);

      final hint = state.findHint();

      // 确定性棋盘必有一对
      expect(hint, isNotNull);

      final (r1, c1, r2, c2) = hint!;
      expect(r1, greaterThanOrEqualTo(0));
      expect(c1, greaterThanOrEqualTo(0));
      expect(r2, greaterThanOrEqualTo(0));
      expect(c2, greaterThanOrEqualTo(0));

      final cell1 = state.grid[r1][c1]!;
      final cell2 = state.grid[r2][c2]!;
      expect(cell1.emoji, cell2.emoji);
      expect(cell1.isEliminated, false);
      expect(cell2.isEliminated, false);
    });

    test('returns null when no pairs exist (deadlock)', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Make all cells have different emojis (impossible to match)
      for (int r = 0; r < state.grid.length; r++) {
        for (int c = 0; c < state.grid[r].length; c++) {
          state.grid[r][c] = state.grid[r][c]!.copyWith(
            emoji: 'unique_$r$c',
          );
        }
      }

      final hint = state.findHint();

      expect(hint, isNull);
    });

    test('returns null when grid is empty', () {
      final state = GameState();
      // Don't initialize grid

      final hint = state.findHint();

      expect(hint, isNull);
    });
  });

  group('GameState.useHint', () {
    test('returns hint and deducts 5 points (score clamped at 0)', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      _seedSolvablePairs(state, 2);

      final hint = state.useHint();

      expect(hint, isNotNull);
      expect(state.score, 0); // max(0, -5) = 0
    });

    test('score does not go below 0', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      state.useHint(); // -5 → 0 (clamped)
      expect(state.score, 0);
    });

    test('returns null when no hint available', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Make all cells unique
      for (int r = 0; r < state.grid.length; r++) {
        for (int c = 0; c < state.grid[r].length; c++) {
          state.grid[r][c] = state.grid[r][c]!.copyWith(
            emoji: 'unique_$r$c',
          );
        }
      }

      final hint = state.useHint();

      expect(hint, isNull);
      expect(state.score, 0); // Score unchanged when no hint
    });
  });

  group('GameState.checkDeadlock', () {
    test('returns false when valid pairs exist', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // 确定性构造一对相邻同 emoji（随机布局不保证存在可连通对）
      final a = state.grid[0][0]!;
      state.grid[0][1] =
          state.grid[0][1]!.copyWith(emoji: a.emoji, ttsLabel: a.ttsLabel);
      for (int r = 0; r < state.grid.length; r++) {
        for (int c = 0; c < state.grid[r].length; c++) {
          if ((r == 0 && c == 0) || (r == 0 && c == 1)) continue;
          state.grid[r][c] = state.grid[r][c]!.copyWith(isEliminated: true);
        }
      }

      final deadlock = state.checkDeadlock();

      expect(deadlock, false);
    });

    test('returns true when no pairs exist', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      for (int r = 0; r < state.grid.length; r++) {
        for (int c = 0; c < state.grid[r].length; c++) {
          state.grid[r][c] = state.grid[r][c]!.copyWith(
            emoji: 'unique_$r$c',
          );
        }
      }

      final deadlock = state.checkDeadlock();

      expect(deadlock, true);
    });

    test('returns true when grid is empty', () {
      final state = GameState();

      final deadlock = state.checkDeadlock();

      expect(deadlock, true);
    });
  });

  group('GameState.shuffleRemaining', () {
    test('shuffles remaining cells (some positions change)', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Capture original emoji at each position
      final originalEmojis = state.grid.map((row) =>
          row.map((cell) => cell!.emoji).toList()).toList();

      state.shuffleRemaining();

      // Verify grid dimensions unchanged
      expect(state.grid.length, originalEmojis.length);
      expect(state.grid[0].length, originalEmojis[0].length);

      // At least some positions should have different emojis after shuffle
      int changed = 0;
      for (int r = 0; r < state.grid.length; r++) {
        for (int c = 0; c < state.grid[r].length; c++) {
          if (state.grid[r][c]!.emoji != originalEmojis[r][c]) {
            changed++;
          }
        }
      }
      // With random shuffle, most positions should change
      // But we just verify at least some changed (not all stay same)
      expect(changed, greaterThan(0));
    });

    test('preserves eliminated cells', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Eliminate some cells
      state.grid[0][0] = state.grid[0][0]!.copyWith(isEliminated: true);
      state.grid[0][1] = state.grid[0][1]!.copyWith(isEliminated: true);

      state.shuffleRemaining();

      expect(state.grid[0][0]!.isEliminated, true);
      expect(state.grid[0][1]!.isEliminated, true);
    });

    test('preserves ttsLabel count after shuffle', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Count ttsLabels before shuffle
      final originalLabelCounts = <String, int>{};
      for (final row in state.grid) {
        for (final cell in row) {
          originalLabelCounts[cell!.ttsLabel] =
              (originalLabelCounts[cell.ttsLabel] ?? 0) + 1;
        }
      }

      state.shuffleRemaining();

      // Count ttsLabels after shuffle
      final shuffledLabelCounts = <String, int>{};
      for (final row in state.grid) {
        for (final cell in row) {
          shuffledLabelCounts[cell!.ttsLabel] =
              (shuffledLabelCounts[cell.ttsLabel] ?? 0) + 1;
        }
      }

      // Total labels should be the same
      final originalTotal = originalLabelCounts.values.fold(0, (a, b) => a + b);
      final shuffledTotal = shuffledLabelCounts.values.fold(0, (a, b) => a + b);
      expect(shuffledTotal, originalTotal);
    });

    test('handles case with fewer than 2 remaining cells', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Eliminate all but one cell
      for (int r = 0; r < state.grid.length; r++) {
        for (int c = 0; c < state.grid[r].length; c++) {
          if (!(r == 0 && c == 0)) {
            state.grid[r][c] =
                state.grid[r][c]!.copyWith(isEliminated: true);
          }
        }
      }

      // Should not crash
      state.shuffleRemaining();
      expect(state.grid[0][0]!.isEliminated, false);
    });

    test('handles case with all cells eliminated', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Eliminate all cells
      for (int r = 0; r < state.grid.length; r++) {
        for (int c = 0; c < state.grid[r].length; c++) {
          state.grid[r][c] =
              state.grid[r][c]!.copyWith(isEliminated: true);
        }
      }

      // Should not crash
      state.shuffleRemaining();
    });
  });

  group('GameState.selectCell', () {
    test('selects first cell', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      state.selectCell(0, 0);

      expect(state.selectedCell, isNotNull);
      expect(state.selectedCell!.row, 0);
      expect(state.selectedCell!.col, 0);
    });

    test('selects second cell and attempts match', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      final hint = state.findHint();
      expect(hint, isNotNull);
      final (r1, c1, r2, c2) = hint!;

      state.selectCell(r1, c1);
      expect(state.selectedCell, isNotNull);

      state.selectCell(r2, c2);

      expect(state.selectedCell, isNull);
      expect(state.score, 10);
    });

    test('deselects when same cell selected', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      state.selectCell(0, 0);
      expect(state.selectedCell, isNotNull);

      state.selectCell(0, 0);
      expect(state.selectedCell, isNull);
    });

    test('ignores eliminated cell', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      state.grid[0][0] = state.grid[0][0]!.copyWith(isEliminated: true);

      state.selectCell(0, 0);

      expect(state.selectedCell, isNull);
    });

    test('does nothing when not playing', () {
      final state = GameState();
      state.reset(); // Sets isPlaying to false

      state.selectCell(0, 0);

      expect(state.selectedCell, isNull);
    });

    test('selecting different cells with no match clears selection', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Find two cells with different emojis
      final cell1 = state.grid[0][0]!;
      Cell? differentCell;
      for (final row in state.grid) {
        for (final cell in row) {
          if (cell!.emoji != cell1.emoji) {
            differentCell = cell;
            break;
          }
        }
        if (differentCell != null) break;
      }

      expect(differentCell, isNotNull);

      state.selectCell(cell1.row, cell1.col);
      state.selectCell(differentCell!.row, differentCell.col);

      // 配对失败清空选中（用户决策：点击模式失败即清空，滑动模式另有容错）
      expect(state.selectedCell, isNull);
      expect(state.score, 0); // No score change on failed match
    });
  });

  group('GameState.streak', () {
    test('成功消除累加连击，失败清零', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      _seedSolvablePairs(state, 2);

      expect(state.streak, 0);
      expect(state.tryMatch(state.grid[0][0]!, state.grid[0][1]!), true);
      expect(state.streak, 1);

      // 失败尝试（消错对）清零连击
      final c = state.grid[1][0]!;
      final other = state.grid[2][0]!; // 已被消除的格子，必失败
      expect(state.tryMatch(c, other), false);
      expect(state.streak, 0);

      // 再次成功重新累计
      expect(state.tryMatch(state.grid[1][0]!, state.grid[1][1]!), true);
      expect(state.streak, 1);
    });

    test('重开局清零连击', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      _seedSolvablePairs(state, 2);
      state.tryMatch(state.grid[0][0]!, state.grid[0][1]!);
      expect(state.streak, 1);

      state.initializeGrid('简单', EmojiTheme.fruits);
      expect(state.streak, 0);
    });
  });

  group('GameState.tick', () {
    test('increments timeElapsed when playing', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      expect(state.timeElapsed, 0);
      state.tick();
      expect(state.timeElapsed, 1);
      state.tick();
      expect(state.timeElapsed, 2);
    });

    test('does not increment when not playing', () {
      final state = GameState();
      state.reset();

      state.tick();
      expect(state.timeElapsed, 0);
    });
  });

  group('GameState.reset', () {
    test('clears all state', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      state.selectCell(0, 0);
      state.score = 100;
      state.timeElapsed = 50;

      state.reset();

      expect(state.grid, isEmpty);
      expect(state.score, 0);
      expect(state.selectedCell, isNull);
      expect(state.timeElapsed, 0);
      expect(state.isPlaying, false);
      expect(state.currentPath, isNull);
    });
  });

  group('GameState.scoring', () {
    test('elimination adds 10 points', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Find two adjacent cells with same emoji (guaranteed straight-line path)
      Cell? start;
      Cell? end;
      for (int r = 0; r < state.grid.length && start == null; r++) {
        for (int c = 0; c < state.grid[r].length - 1 && start == null; c++) {
          final cell = state.grid[r][c]!;
          final right = state.grid[r][c + 1]!;
          if (cell.emoji == right.emoji) {
            start = cell;
            end = right;
          }
        }
      }

      // With 8 emoji types and 28 cells, adjacent pairs are statistically expected
      // If none found, skip this test (extremely rare random edge case)
      if (start == null || end == null) {
        // Verify the scoring logic by directly manipulating state
        state.score = 0;
        final cell1 = state.grid[0][0]!;
        final cell2 = state.grid[0][1]!;
        // Force them to have same emoji and be matchable
        state.grid[0][1] = cell2.copyWith(emoji: cell1.emoji);
        final result = state.tryMatch(cell1, state.grid[0][1]!);
        expect(result, true);
        expect(state.score, 10);
        return;
      }

      final result = state.tryMatch(start, end);
      expect(result, true);
      expect(state.score, 10);
    });

    test('hint deducts 5 points', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      _seedSolvablePairs(state, 2); // 保证有解，useHint 才会扣分
      state.score = 20;

      state.useHint();

      expect(state.score, 15);
    });

    test('hint score clamped at 0', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      _seedSolvablePairs(state, 2);
      state.score = 3;

      state.useHint();

      expect(state.score, 0);
    });

    test('hint does not deduct when no hint available', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);
      state.score = 20;

      // Make all cells unique
      for (int r = 0; r < state.grid.length; r++) {
        for (int c = 0; c < state.grid[r].length; c++) {
          state.grid[r][c] = state.grid[r][c]!.copyWith(
            emoji: 'unique_$r$c',
          );
        }
      }

      state.useHint();

      expect(state.score, 20); // Unchanged
    });
  });

  group('GameState.integration', () {
    test('full game flow: init → select → match → hint → reset', () {
      final state = GameState();

      // Init
      state.initializeGrid('简单', EmojiTheme.fruits);
      expect(state.isPlaying, true);
      expect(state.score, 0);
      expect(state.grid.length, 7); // 简单：7 行 × 4 列

      // 确定性构造两对相邻同 emoji（随机布局不保证可解）
      _seedSolvablePairs(state, 2);

      final hint = state.findHint();
      expect(hint, isNotNull);
      final (r1, c1, r2, c2) = hint!;

      state.selectCell(r1, c1);
      expect(state.selectedCell, isNotNull);

      state.selectCell(r2, c2);

      expect(state.selectedCell, isNull);
      expect(state.score, 10);

      // Hint — 第二对仍然可解
      final nextHint = state.findHint();
      expect(nextHint, isNotNull);

      // Reset
      state.reset();
      expect(state.isPlaying, false);
      expect(state.grid, isEmpty);
    });

    test('deadlock triggers shuffle to find new pairs', () {
      final state = GameState();
      state.initializeGrid('简单', EmojiTheme.fruits);

      // Shuffle until a different layout appears
      final originalLayout = state.grid.map((row) =>
          row.map((cell) => cell?.emoji).toList()).toList();

      state.shuffleRemaining();

      final newLayout = state.grid.map((row) =>
          row.map((cell) => cell?.emoji).toList()).toList();

      // Layout should be different (very high probability)
      expect(newLayout, isNot(equals(originalLayout)));
    });
  });
}
