import 'package:flutter_test/flutter_test.dart';
import 'package:link_game/services/update_service.dart';

void main() {
  group('UpdateService.parseVersionCodeFromAsset', () {
    test('从标准资产名解析 versionCode', () {
      expect(UpdateService.parseVersionCodeFromAsset('linkgame-1.1.0+2.apk'), 2);
      expect(UpdateService.parseVersionCodeFromAsset('linkgame-2.0.0+10.apk'), 10);
    });

    test('大小写不敏感', () {
      expect(UpdateService.parseVersionCodeFromAsset('LinkGame-1.0.0+3.APK'), 3);
    });

    test('非 APK 或缺 versionCode 时返回 null', () {
      expect(UpdateService.parseVersionCodeFromAsset('app-release.apk'), isNull);
      expect(UpdateService.parseVersionCodeFromAsset('linkgame-1.1.0.apk'), isNull);
      expect(UpdateService.parseVersionCodeFromAsset('notes.txt'), isNull);
      expect(UpdateService.parseVersionCodeFromAsset('linkgame-1.1.0+abc.apk'), isNull);
    });
  });
}
