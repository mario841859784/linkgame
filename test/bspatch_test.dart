import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/utils/bspatch.dart';

Uint8List _fixture(String name) =>
    Uint8List.fromList(File('test/fixtures/$name').readAsBytesSync());

void main() {
  group('Bspatch', () {
    test('用真实 bsdiff fixture 重建新文件（diff/extra/seek 全覆盖）', () {
      final oldData = _fixture('old.bin');
      final newData = _fixture('new.bin');
      final patchData = _fixture('old-to-new.patch');

      final result = Bspatch.patch(oldData, patchData);

      expect(result.length, newData.length);
      // 逐字节一致性 —— 这是 v2 签名能原样保留的前提
      expect(result, orderedEquals(newData));
    });

    test('补丁过小抛 FormatException', () {
      expect(
        () => Bspatch.patch(Uint8List(10), Uint8List(16)),
        throwsFormatException,
      );
    });

    test('magic 不对抛 FormatException', () {
      final bad = Uint8List.fromList('NOTAPATCH______________'.codeUnits);
      expect(() => Bspatch.patch(Uint8List(10), bad), throwsFormatException);
    });

    test('截断的补丁抛 FormatException（不产生错误输出）', () {
      final patchData = _fixture('old-to-new.patch');
      final truncated = Uint8List.sublistView(patchData, 0, 100);
      expect(
        () => Bspatch.patch(_fixture('old.bin'), Uint8List.fromList(truncated)),
        throwsFormatException,
      );
    });
  });
}
