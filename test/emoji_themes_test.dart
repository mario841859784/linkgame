import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/models/emoji_themes.dart';

void main() {
  group('EmojiTheme enum', () {
    test('has exactly 6 themes', () {
      expect(EmojiTheme.values.length, 6);
    });

    test('contains all expected themes', () {
      expect(EmojiTheme.values, contains(EmojiTheme.fruits));
      expect(EmojiTheme.values, contains(EmojiTheme.animals));
      expect(EmojiTheme.values, contains(EmojiTheme.flowers));
      expect(EmojiTheme.values, contains(EmojiTheme.food));
      expect(EmojiTheme.values, contains(EmojiTheme.vehicles));
      expect(EmojiTheme.values, contains(EmojiTheme.sports));
    });
  });

  group('Theme names', () {
    test('fruit theme name is in Chinese', () {
      expect(EmojiTheme.fruits.name, '水果');
    });

    test('animal theme name is in Chinese', () {
      expect(EmojiTheme.animals.name, '动物');
    });

    test('flower theme name is in Chinese', () {
      expect(EmojiTheme.flowers.name, '花卉');
    });

    test('food theme name is in Chinese', () {
      expect(EmojiTheme.food.name, '食物');
    });

    test('vehicle theme name is in Chinese', () {
      expect(EmojiTheme.vehicles.name, '交通工具');
    });

    test('sport theme name is in Chinese', () {
      expect(EmojiTheme.sports.name, '运动');
    });
  });

  group('Emojis per theme', () {
    test('fruits theme has 8 emojis', () {
      expect(EmojiTheme.fruits.emojis.length, 8);
    });

    test('animals theme has 8 emojis', () {
      expect(EmojiTheme.animals.emojis.length, 8);
    });

    test('flowers theme has 8 emojis', () {
      expect(EmojiTheme.flowers.emojis.length, 8);
    });

    test('food theme has 8 emojis', () {
      expect(EmojiTheme.food.emojis.length, 8);
    });

    test('vehicles theme has 8 emojis', () {
      expect(EmojiTheme.vehicles.emojis.length, 8);
    });

    test('sports theme has 8 emojis', () {
      expect(EmojiTheme.sports.emojis.length, 8);
    });

    test('all emojis are non-empty strings', () {
      for (final theme in EmojiTheme.values) {
        for (final emoji in theme.emojis) {
          expect(emoji.isNotEmpty, true,
              reason: '${theme.name} has an empty emoji');
        }
      }
    });

    test('all emojis within a theme are unique', () {
      for (final theme in EmojiTheme.values) {
        final unique = theme.emojis.toSet();
        expect(unique.length, theme.emojis.length,
            reason: '${theme.name} has duplicate emojis');
      }
    });
  });

  group('TTS Labels per theme', () {
    test('fruits theme has 8 ttsLabels', () {
      expect(EmojiTheme.fruits.ttsLabels.length, 8);
    });

    test('animals theme has 8 ttsLabels', () {
      expect(EmojiTheme.animals.ttsLabels.length, 8);
    });

    test('flowers theme has 8 ttsLabels', () {
      expect(EmojiTheme.flowers.ttsLabels.length, 8);
    });

    test('food theme has 8 ttsLabels', () {
      expect(EmojiTheme.food.ttsLabels.length, 8);
    });

    test('vehicles theme has 8 ttsLabels', () {
      expect(EmojiTheme.vehicles.ttsLabels.length, 8);
    });

    test('sports theme has 8 ttsLabels', () {
      expect(EmojiTheme.sports.ttsLabels.length, 8);
    });

    test('ttsLabel count matches emoji count for all themes', () {
      for (final theme in EmojiTheme.values) {
        expect(theme.ttsLabels.length, theme.emojis.length,
            reason: '${theme.name} ttsLabel count != emoji count');
      }
    });

    test('all ttsLabels are non-empty Chinese strings', () {
      for (final theme in EmojiTheme.values) {
        for (final label in theme.ttsLabels) {
          expect(label.isNotEmpty, true,
              reason: '${theme.name} has an empty ttsLabel');
        }
      }
    });
  });

  group('Theme emoji-label mapping', () {
    test('fruits emojis and ttsLabels correspond correctly', () {
      final theme = EmojiTheme.fruits;
      expect(theme.emojis[0], '🍎');
      expect(theme.ttsLabels[0], '苹果');
      expect(theme.emojis[1], '🍌');
      expect(theme.ttsLabels[1], '香蕉');
      expect(theme.emojis[7], '🍒');
      expect(theme.ttsLabels[7], '樱桃');
    });

    test('animals emojis and ttsLabels correspond correctly', () {
      final theme = EmojiTheme.animals;
      expect(theme.emojis[0], '🐶');
      expect(theme.ttsLabels[0], '小狗');
      expect(theme.emojis[7], '🐯');
      expect(theme.ttsLabels[7], '老虎');
    });
  });
}
