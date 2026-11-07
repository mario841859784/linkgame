import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/services/content_service.dart';
import 'package:link_game/utils/tts_service.dart';

void main() {
  Map<String, dynamic> validContent({int rev = 2}) => <String, dynamic>{
        'rev': rev,
        'praisePhrases': <String>['你好棒', '真厉害', '厉害了'],
        'messages': <String, String>{
          'hint': '试试看',
          'noPairShuffle': '重排一下',
        },
        'ttsRateDefault': 0.35,
      };

  group('ContentService.validateContent', () {
    test('接受合法内容', () {
      expect(ContentService.validateContent(validContent()), isNotNull);
    });

    test('拒绝非整数 rev', () {
      final raw = validContent()..['rev'] = '3';
      expect(ContentService.validateContent(raw), isNull);
    });

    test('拒绝台词过少的池子', () {
      final raw = validContent()..['praisePhrases'] = ['真棒', '厉害'];
      expect(ContentService.validateContent(raw), isNull);
    });

    test('空台词被静默过滤，剩余足够则接受', () {
      final raw = validContent()..['praisePhrases'] = ['真棒', '', '  ', 'ok', '好'];
      final cleaned = ContentService.validateContent(raw);
      expect(cleaned, isNotNull);
      expect(cleaned!['praisePhrases'], <String>['真棒', 'ok', '好']);
    });

    test('空台词过滤后不足 3 条则拒绝', () {
      final raw = validContent()..['praisePhrases'] = ['真棒', '', '   '];
      expect(ContentService.validateContent(raw), isNull);
    });

    test('拒绝超长台词', () {
      final raw = validContent()..['praisePhrases'] = ['a' * 31, '真棒', '厉害'];
      expect(ContentService.validateContent(raw), isNull);
    });

    test('拒绝空提示文案', () {
      final raw = validContent()
        ..['messages'] = {'hint': '  ', 'noPairShuffle': '重排一下'};
      expect(ContentService.validateContent(raw), isNull);
    });

    test('拒绝越界语速', () {
      final raw = validContent()..['ttsRateDefault'] = 0.9;
      expect(ContentService.validateContent(raw), isNull);
    });
  });

  group('ContentService.applyContent', () {
    test('应用合法内容并更新读取接口', () {
      final ok = ContentService.instance.applyContent(validContent(rev: 3));
      expect(ok, true);
      expect(ContentService.instance.praisePhrases,
          <String>['你好棒', '真厉害', '厉害了']);
      expect(ContentService.instance.hintMessage, '试试看');
      expect(ContentService.instance.noPairMessage, '重排一下');
      expect(ContentService.instance.ttsRateDefault, 0.35);
      expect(ContentService.instance.appliedRev, 3);
    });

    test('拒绝非法内容并保持原状', () {
      final before = ContentService.instance.praisePhrases;
      final ok = ContentService.instance.applyContent(<String, dynamic>{
        'rev': 'bad',
      });
      expect(ok, false);
      expect(ContentService.instance.praisePhrases, before);
    });
  });

  test('randomPraise 使用热更后的台词池', () {
    final pool = ContentService.instance.praisePhrases;
    for (int i = 0; i < 30; i++) {
      expect(pool, contains(TtsService.randomPraise()));
    }
  });
}
