import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/utils/tts_service.dart';

void main() {
  group('TtsService.randomPraise', () {
    test('returns non-empty phrase', () {
      expect(TtsService.randomPraise(), isNotEmpty);
    });

    test('随机 100 次应覆盖多条不同台词', () {
      final drawn = <String>{};
      for (int i = 0; i < 100; i++) {
        drawn.add(TtsService.randomPraise());
      }
      expect(drawn.length, greaterThanOrEqualTo(4),
          reason: '台词池退化或过小会导致随机分布异常');
    });
  });
}
