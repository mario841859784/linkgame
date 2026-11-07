import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// GitHub Release 上的远端版本信息
class RemoteRelease {
  final String tagName;
  final String versionName;
  final int versionCode;

  /// APK 资产的 GitHub 下载地址（下载时按需拼镜像前缀）
  final String apkDownloadUrl;

  const RemoteRelease({
    required this.tagName,
    required this.versionName,
    required this.versionCode,
    required this.apkDownloadUrl,
  });
}

/// 应用内自更新服务
///
/// 检查 GitHub Releases 最新版本的 APK（资产文件名需形如
/// `linkgame-1.1.0+2.apk`，以 +versionCode 判断是否需要升级），
/// 多源回退下载后唤起系统安装器。所有失败静默，不打扰老年用户。
class UpdateService {
  UpdateService._();

  static final UpdateService _instance = UpdateService._();
  static UpdateService get instance => _instance;

  static const String _repo = 'mario841859784/linkgame';
  static const String _apiLatestUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  /// 下载镜像前缀（空字符串 = GitHub 直连，按顺序回退）
  static const List<String> _downloadMirrors = [
    '',
    'https://ghproxy.net/',
    'https://gh-proxy.com/',
  ];

  static const Duration _apiTimeout = Duration(seconds: 8);
  static const int _minApkBytes = 1 * 1024 * 1024; // 1MB 完整性下限

  PackageInfo? _packageInfo;
  RemoteRelease? _cachedLatest;

  /// 从 APK 资产名解析 versionCode：linkgame-1.1.0+2.apk → 2
  static int? parseVersionCodeFromAsset(String name) {
    final m = RegExp(r'\+(\d+)\.apk$').firstMatch(name.toLowerCase());
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  /// 当前应用的 versionCode
  Future<int> currentVersionCode() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return int.tryParse(_packageInfo!.buildNumber) ?? 0;
  }

  /// 当前应用版本名，如 1.1.0
  Future<String> currentVersionName() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!.version;
  }

  /// 查询最新版本；无更新/网络失败返回 null
  Future<RemoteRelease?> checkLatest() async {
    if (kIsWeb) return null;
    try {
      final resp = await http.get(
        Uri.parse(_apiLatestUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'link_game-app',
        },
      ).timeout(_apiTimeout);
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data is! Map<String, dynamic>) return null;

      // 找 APK 资产并解析 versionCode
      final assets = data['assets'];
      if (assets is! List) return null;
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = asset['name'];
        final url = asset['browser_download_url'];
        if (name is! String || url is! String) continue;
        if (!name.toLowerCase().endsWith('.apk')) continue;

        final code = parseVersionCodeFromAsset(name);
        if (code == null) continue;

        final current = await currentVersionCode();
        if (code <= current) return null;

        return RemoteRelease(
          tagName: (data['tag_name'] as String?) ?? '',
          versionName: name.substring(0, name.lastIndexOf('+')).split('-').last,
          versionCode: code,
          apkDownloadUrl: url,
        );
      }
      return null;
    } catch (e) {
      debugPrint('UpdateService: 检查更新失败 - $e');
      return null;
    }
  }

  /// 本次运行只检查一次（主菜单横幅用）
  Future<RemoteRelease?> checkOncePerRun() async {
    _cachedLatest ??= await checkLatest();
    return _cachedLatest;
  }

  /// 下载 APK 到临时目录（多源回退，[onProgress] 0.0~1.0），返回本地路径
  Future<String> downloadApk(
    RemoteRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/linkgame-${release.versionName}+${release.versionCode}.apk');
    if (await file.exists()) await file.delete();

    Object? lastError;
    for (final mirror in _downloadMirrors) {
      try {
        final request = http.Request('GET', Uri.parse('$mirror${release.apkDownloadUrl}'));
        final resp = await http.Client().send(request).timeout(const Duration(minutes: 5));
        if (resp.statusCode != 200) {
          lastError = 'HTTP ${resp.statusCode}';
          continue;
        }

        final total = resp.contentLength ?? 0;
        int received = 0;
        final sink = file.openWrite();
        try {
          await for (final chunk in resp.stream) {
            received += chunk.length;
            sink.add(chunk);
            if (total > 0 && onProgress != null) {
              onProgress((received / total).clamp(0.0, 1.0));
            }
          }
          await sink.flush();
          await sink.close();
        } catch (_) {
          await sink.close();
          rethrow;
        }

        if (received < _minApkBytes) {
          lastError = '下载不完整（$received 字节）';
          continue;
        }
        return file.path;
      } catch (e) {
        lastError = e;
        if (await file.exists()) await file.delete();
      }
    }
    throw StateError('所有下载源均失败: $lastError');
  }

  /// 唤起系统安装器；返回是否成功发起
  Future<bool> installApk(String apkPath) async {
    if (kIsWeb) return false;
    try {
      final result = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );
      return result.type == ResultType.done;
    } catch (e) {
      debugPrint('UpdateService: 唤起安装失败 - $e');
      return false;
    }
  }
}
