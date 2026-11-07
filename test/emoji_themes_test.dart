import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/models/emoji_themes.dart';

void main() {
  group('EmojiTheme enum', () {
    test('has exactly 11 themes', () {
      expect(EmojiTheme.values.length, 11);
    });

    test('contains all expected themes', () {
      expect(EmojiTheme.values, contains(EmojiTheme.fruits));
      expect(EmojiTheme.values, contains(EmojiTheme.animals));
      expect(EmojiTheme.values, contains(EmojiTheme.flowers));
      expect(EmojiTheme.values, contains(EmojiTheme.food));
      expect(EmojiTheme.values, contains(EmojiTheme.vehicles));
      expect(EmojiTheme.values, contains(EmojiTheme.sports));
      expect(EmojiTheme.values, contains(EmojiTheme.dailyItems));
      expect(EmojiTheme.values, contains(EmojiTheme.weatherNature));
      expect(EmojiTheme.values, contains(EmojiTheme.seaCreatures));
      expect(EmojiTheme.values, contains(EmojiTheme.musicInstruments));
      expect(EmojiTheme.values, contains(EmojiTheme.officeSupplies));
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

    test('daily items theme name is in Chinese', () {
      expect(EmojiTheme.dailyItems.name, '日常用品');
    });

    test('weather nature theme name is in Chinese', () {
      expect(EmojiTheme.weatherNature.name, '天气自然');
    });

    test('sea creatures theme name is in Chinese', () {
      expect(EmojiTheme.seaCreatures.name, '海洋生物');
    });

    test('music instruments theme name is in Chinese', () {
      expect(EmojiTheme.musicInstruments.name, '音乐乐器');
    });

    test('office supplies theme name is in Chinese', () {
      expect(EmojiTheme.officeSupplies.name, '办公学习');
    });
  });

  group('Emojis per theme', () {
    test('every theme has 16 emojis', () {
      for (final theme in EmojiTheme.values) {
        expect(theme.emojis.length, 16,
            reason: '${theme.name} emoji count != 16');
      }
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
    test('every theme has 16 ttsLabels', () {
      for (final theme in EmojiTheme.values) {
        expect(theme.ttsLabels.length, 16,
            reason: '${theme.name} ttsLabel count != 16');
      }
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
