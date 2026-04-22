import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/models/cell.dart';

void main() {
  group('Cell Constructor', () {
    test('creates cell with all required properties', () {
      const cell = Cell(
        id: 1,
        row: 2,
        col: 3,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      expect(cell.id, 1);
      expect(cell.row, 2);
      expect(cell.col, 3);
      expect(cell.emoji, '🍎');
      expect(cell.ttsLabel, '苹果');
      expect(cell.isEliminated, false);
    });

    test('creates cell with isEliminated set to true', () {
      const cell = Cell(
        id: 1,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
        isEliminated: true,
      );

      expect(cell.isEliminated, true);
    });
  });

  group('Cell copyWith', () {
    test('returns identical cell when no arguments provided', () {
      const original = Cell(
        id: 1,
        row: 2,
        col: 3,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      final copy = original.copyWith();

      expect(copy, equals(original));
    });

    test('updates only specified fields', () {
      const original = Cell(
        id: 1,
        row: 2,
        col: 3,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      final updated = original.copyWith(
        emoji: '🍌',
        isEliminated: true,
      );

      expect(updated.id, 1);
      expect(updated.row, 2);
      expect(updated.col, 3);
      expect(updated.emoji, '🍌');
      expect(updated.ttsLabel, '苹果');
      expect(updated.isEliminated, true);
    });

    test('updates all fields', () {
      const original = Cell(
        id: 1,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      final updated = original.copyWith(
        id: 99,
        row: 5,
        col: 6,
        emoji: '🍇',
        ttsLabel: '葡萄',
        isEliminated: true,
      );

      expect(updated.id, 99);
      expect(updated.row, 5);
      expect(updated.col, 6);
      expect(updated.emoji, '🍇');
      expect(updated.ttsLabel, '葡萄');
      expect(updated.isEliminated, true);
    });
  });

  group('Cell equality', () {
    test('two cells with same properties are equal', () {
      const a = Cell(
        id: 1,
        row: 2,
        col: 3,
        emoji: '🍎',
        ttsLabel: '苹果',
      );
      const b = Cell(
        id: 1,
        row: 2,
        col: 3,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      expect(a, equals(b));
    });

    test('two cells with different id are not equal', () {
      const a = Cell(
        id: 1,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
      );
      const b = Cell(
        id: 2,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      expect(a, isNot(equals(b)));
    });

    test('two cells with different row are not equal', () {
      const a = Cell(id: 1, row: 0, col: 0, emoji: '🍎', ttsLabel: '苹果');
      const b = Cell(id: 1, row: 1, col: 0, emoji: '🍎', ttsLabel: '苹果');

      expect(a, isNot(equals(b)));
    });

    test('two cells with different col are not equal', () {
      const a = Cell(id: 1, row: 0, col: 0, emoji: '🍎', ttsLabel: '苹果');
      const b = Cell(id: 1, row: 0, col: 1, emoji: '🍎', ttsLabel: '苹果');

      expect(a, isNot(equals(b)));
    });

    test('two cells with different emoji are not equal', () {
      const a = Cell(id: 1, row: 0, col: 0, emoji: '🍎', ttsLabel: '苹果');
      const b = Cell(id: 1, row: 0, col: 0, emoji: '🍌', ttsLabel: '香蕉');

      expect(a, isNot(equals(b)));
    });

    test('two cells with different ttsLabel are not equal', () {
      const a = Cell(id: 1, row: 0, col: 0, emoji: '🍎', ttsLabel: '苹果');
      const b = Cell(id: 1, row: 0, col: 0, emoji: '🍎', ttsLabel: 'banana');

      expect(a, isNot(equals(b)));
    });

    test('two cells with different isEliminated are not equal', () {
      const a = Cell(
        id: 1,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
      );
      const b = Cell(
        id: 1,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
        isEliminated: true,
      );

      expect(a, isNot(equals(b)));
    });

    test('identical objects are equal', () {
      const cell = Cell(
        id: 1,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      expect(cell == cell, true);
    });

    test('comparing with non-Cell returns false', () {
      const cell = Cell(
        id: 1,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      expect(cell == 'not a cell', false);
    });
  });

  group('Cell hashCode', () {
    test('equal cells have equal hashCodes', () {
      const a = Cell(
        id: 1,
        row: 2,
        col: 3,
        emoji: '🍎',
        ttsLabel: '苹果',
      );
      const b = Cell(
        id: 1,
        row: 2,
        col: 3,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      expect(a.hashCode, equals(b.hashCode));
    });

    test('different cells have different hashCodes (likely)', () {
      const a = Cell(
        id: 1,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
      );
      const b = Cell(
        id: 2,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      expect(a.hashCode, isNot(equals(b.hashCode)));
    });
  });

  group('Cell toString', () {
    test('returns formatted string with all properties', () {
      const cell = Cell(
        id: 42,
        row: 3,
        col: 5,
        emoji: '🍎',
        ttsLabel: '苹果',
        isEliminated: true,
      );

      final result = cell.toString();

      expect(result, contains('Cell'));
      expect(result, contains('id:42'));
      expect(result, contains('row:3'));
      expect(result, contains('col:5'));
      expect(result, contains('emoji:🍎'));
      expect(result, contains('ttsLabel:苹果'));
      expect(result, contains('eliminated:true'));
    });

    test('shows eliminated:false when not eliminated', () {
      const cell = Cell(
        id: 1,
        row: 0,
        col: 0,
        emoji: '🍎',
        ttsLabel: '苹果',
      );

      expect(cell.toString(), contains('eliminated:false'));
    });
  });
}
