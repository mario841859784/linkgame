import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:link_game/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

Uint8List _fixture(String name) =>
    Uint8List.fromList(File('test/fixtures/$name').readAsBytesSync());

RemoteRelease _release(String name, int code) => RemoteRelease(
      tagName: 'v$name',
      versionName: name,
      versionCode: code,
      apkDownloadUrl:
          'https://github.com/mario841859784/linkgame/releases/download/v$name/linkgame-$name+$code.apk',
    );

/// 直连（最后一个源）的 GitHub 资产 URL
const String _directUrl =
    'https://github.com/mario841859784/linkgame/releases/download';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('update_service_test');
    UpdateService.tempDirectoryResolver = () async => tempDir;
    UpdateService.clockOverride = null;
    UpdateService.clientFactory = null;
    PackageInfo.setMockInitialValues(
      appName: 'linkgame',
      packageName: 'com.example.link_game',
      version: '1.4.4',
      buildNumber: '18',
      buildSignature: '',
    );
  });

  tearDown(() {
    UpdateService.tempDirectoryResolver = null;
    UpdateService.clockOverride = null;
    UpdateService.clientFactory = null;
    tempDir.deleteSync(recursive: true);
  });

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

  group('UpdateService 多源下载', () {
    test('镜像优先、直连垫底', () async {
      final requested = <String>[];
      UpdateService.clientFactory = () => MockClient.streaming((req, _) async {
            requested.add(req.url.toString());
            return http.StreamedResponse(const Stream.empty(), 404);
          });

      await expectLater(
        UpdateService.instance.downloadApk(_release('1.5.0', 19)),
        throwsA(isA<StateError>()),
      );
      expect(requested, hasLength(5));
      expect(requested.first, startsWith('https://ghfast.top/'));
      expect(requested[3], startsWith('https://github.moeyy.xyz/'));
      expect(requested.last, '$_directUrl/v1.5.0/linkgame-1.5.0+19.apk');
    });

    test('慢速源停滞自动断开，下一源断点续传拼出完整文件', () async {
      var now = DateTime(2026, 1, 1);
      UpdateService.clockOverride = () => now;

      // 慢速源交付 20 字节前缀（4 块 × 5 字节，块间隔 2s，窗口 8s 内远低于阈值）
      const headLen = 20;
      final tail = List<int>.filled(1 << 20, 9); // 快速源补齐至 ≥1MB
      final full = <int>[...List<int>.filled(headLen, 7), ...tail];
      final rangeSeen = <String?>[];
      var ghfastRequests = 0;

      UpdateService.clientFactory = () => MockClient.streaming((req, _) async {
            final url = req.url.toString();
            if (url.startsWith('https://ghfast.top/')) {
              ghfastRequests++;
              return http.StreamedResponse(
                chunkStream(
                    (_) => const [7, 7, 7, 7, 7], 6,
                    () => now = now.add(const Duration(seconds: 2))),
                200,
                contentLength: headLen,
              );
            }
            // 第二个源（ghproxy.net）：应带 Range 续传
            rangeSeen.add(req.headers['Range']);
            final offset = int.parse(
                (req.headers['Range'] ?? 'bytes=0-').substring(6).split('-').first);
            return http.StreamedResponse(
              Stream.value(Uint8List.fromList(full.sublist(offset))),
              206,
              contentLength: full.length - offset,
              headers: {
                'content-range': 'bytes $offset-${full.length - 1}/${full.length}',
              },
            );
          });

      final path = await UpdateService.instance.downloadApk(_release('1.5.0', 19));
      expect(ghfastRequests, 1);
      expect(rangeSeen.single, 'bytes=$headLen-');
      expect(File(path).readAsBytesSync(), orderedEquals(full));
    });

    test('206 的 Content-Range 起始偏移与断点不符时换源，不写坏文件', () async {
      var now = DateTime(2026, 1, 1);
      UpdateService.clockOverride = () => now;

      const headLen = 20;
      final tail = List<int>.filled(1 << 20, 9);
      final full = <int>[...List<int>.filled(headLen, 7), ...tail];
      final statuses = <int>[];

      UpdateService.clientFactory = () => MockClient.streaming((req, _) async {
            final url = req.url.toString();
            if (url.startsWith('https://ghfast.top/')) {
              statuses.add(200);
              return http.StreamedResponse(
                chunkStream(
                    (_) => const [7, 7, 7, 7, 7], 6,
                    () => now = now.add(const Duration(seconds: 2))),
                200,
                contentLength: headLen,
              );
            }
            if (url.startsWith('https://ghproxy.net/')) {
              // 伪造与断点不符的 206（起始 0），应被拒绝
              statuses.add(206);
              return http.StreamedResponse(
                Stream.value(Uint8List.fromList(full)),
                206,
                contentLength: full.length,
                headers: {'content-range': 'bytes 0-${full.length - 1}/${full.length}'},
              );
            }
            statuses.add(200);
            return http.StreamedResponse(
              Stream.value(Uint8List.fromList(full)),
              200,
              contentLength: full.length,
            );
          });

      final path = await UpdateService.instance.downloadApk(_release('1.5.0', 19));
      expect(statuses, orderedEquals(const [200, 206, 200]));
      expect(File(path).readAsBytesSync(), orderedEquals(full));
    });

    test('下一源不支持 Range（200）时丢弃旧前缀从头下', () async {
      var now = DateTime(2026, 1, 1);
      UpdateService.clockOverride = () => now;

      const headLen = 20;
      final full = <int>[
        ...List<int>.filled(headLen, 7),
        ...List<int>.filled((1 << 20) - headLen, 5),
      ];
      final rangeSeen = <String?>[];

      UpdateService.clientFactory = () => MockClient.streaming((req, _) async {
            final url = req.url.toString();
            if (url.startsWith('https://ghfast.top/')) {
              return http.StreamedResponse(
                chunkStream(
                    (_) => const [7, 7, 7, 7, 7], 6,
                    () => now = now.add(const Duration(seconds: 2))),
                200,
                contentLength: headLen,
              );
            }
            rangeSeen.add(req.headers['Range']);
            // 忽略 Range，仍回 200 全量
            return http.StreamedResponse(
              Stream.value(Uint8List.fromList(full)),
              200,
              contentLength: full.length,
            );
          });

      final path = await UpdateService.instance.downloadApk(_release('1.5.0', 19));
      expect(rangeSeen.single, 'bytes=$headLen-');
      final saved = File(path).readAsBytesSync();
      expect(saved, orderedEquals(full)); // 无追加残留
    });

    test('最后一个源（直连）不因慢速中断，慢而能完成', () async {
      var now = DateTime(2026, 1, 1);
      UpdateService.clockOverride = () => now;

      // 直连以约 10KB/s 慢速交付 1.1MB：每个 8s 窗口只有 1 块 100KB
      const chunk = 100 * 1024;
      const chunkCount = 11;
      final data = List<int>.generate(chunk * chunkCount, (i) => i & 0xFF);
      final urls = <String>[];

      UpdateService.clientFactory = () => MockClient.streaming((req, _) async {
            final url = req.url.toString();
            urls.add(url);
            if (url != '$_directUrl/v1.5.0/linkgame-1.5.0+19.apk') {
              return http.StreamedResponse(const Stream.empty(), 404);
            }
            return http.StreamedResponse(
              chunkStream(
                  (i) => data.sublist(i * chunk, (i + 1) * chunk),
                  chunkCount,
                  () => now = now.add(const Duration(seconds: 10))),
              200,
              contentLength: data.length,
            );
          });

      final path = await UpdateService.instance.downloadApk(_release('1.5.0', 19));
      expect(urls, hasLength(5)); // 四个镜像 404 后落到直连
      expect(File(path).readAsBytesSync(), orderedEquals(data));
    });
  });

  group('UpdateService 增量补丁', () {
    test('镜像失败回退后下载补丁并重建出新 APK', () async {
      final oldData = _fixture('old.bin');
      final newData = _fixture('new.bin');
      final patchData = _fixture('old-to-new.patch');

      PackageInfo.setMockInitialValues(
        appName: 'linkgame',
        packageName: 'com.example.link_game',
        version: '1.4.4',
        buildNumber: '17',
        buildSignature: '',
      );
      final installedPath = '${tempDir.path}/installed-old.bin';
      File(installedPath).writeAsBytesSync(oldData);
      const channel = MethodChannel('linkgame/app_info');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInstalledApkPath') return installedPath;
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      final requested = <String>[];
      UpdateService.clientFactory = () => MockClient.streaming((req, _) async {
            requested.add(req.url.toString());
            if (req.url.host == 'ghfast.top') {
              return http.StreamedResponse(const Stream.empty(), 404);
            }
            return http.StreamedResponse(
              Stream.value(patchData),
              200,
              contentLength: patchData.length,
            );
          });

      final release = RemoteRelease(
        tagName: 'v1.5.0',
        versionName: '1.5.0',
        versionCode: 19,
        apkDownloadUrl: '$_directUrl/v1.5.0/linkgame-1.5.0+19.apk',
        patches: [
          PatchInfo(
            fromCode: 17,
            fromSha256: crypto.sha256.convert(oldData).toString(),
            asset: 'linkgame-1.4.4-to-1.5.0.patch',
            size: patchData.length,
            sha256: crypto.sha256.convert(patchData).toString(),
            outSize: newData.length,
            outSha256: crypto.sha256.convert(newData).toString(),
          ),
        ],
      );

      final path = await UpdateService.instance.downloadUpdate(release);
      expect(requested, hasLength(2));
      expect(requested.first, contains('/linkgame-1.4.4-to-1.5.0.patch'));
      expect(File(path).readAsBytesSync(), orderedEquals(newData));
    });
  });
}

/// 生成 [chunkCount] 块数据流，第 i 块内容由 [chunkAt] 提供，
/// 每块交付后调用 [tick] 推进假时钟。
///
/// async* 惰性求值：yield 挂起直到消费方取走事件，因此「先 yield 再推进时钟」
/// 保证每块被消费时的采样时刻严格递增，可精确驱动慢速监视器。
Stream<List<int>> chunkStream(List<int> Function(int index) chunkAt,
    int chunkCount, void Function() tick) async* {
  for (var i = 0; i < chunkCount; i++) {
    yield chunkAt(i);
    tick();
  }
}
