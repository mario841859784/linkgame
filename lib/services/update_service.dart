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

/// 一次更新检查的结果
class UpdateCheckOutcome {
  final RemoteRelease? release; // 非空 = 有新版本

  /// 检查是否成功；false = 网络失败（不代表已是最新）
  final bool succeeded;

  const UpdateCheckOutcome({this.release, required this.succeeded});

  static const UpdateCheckOutcome failed =
      UpdateCheckOutcome(succeeded: false);
  static const UpdateCheckOutcome upToDate = UpdateCheckOutcome(succeeded: true);
}

/// 应用内自更新服务
///
/// 版本检查双源回退：
/// 1. GitHub API releases/latest（海外网络直连可用）
/// 2. tag `hotfix` release 上的 latest.json（与内容热更同一镜像通道，
///    国内网络可达；由 scripts/release.sh 随每次发版更新）
///
/// APK 资产名需形如 `linkgame-1.1.1+3.apk`，以 +versionCode 判断是否升级。
/// 所有失败静默降级，不打扰老年用户。
class UpdateService {
  UpdateService._();

  static final UpdateService _instance = UpdateService._();
  static UpdateService get instance => _instance;

  static const String _repo = 'mario841859784/linkgame';
  static const String _apiLatestUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  /// APK 下载镜像前缀（空字符串 = GitHub 直连，按顺序回退）
  /// 注意：这些公共镜像存活率会波动，失效时从此列表移除并补充新镜像即可
  static const List<String> _downloadMirrors = [
    '',
    'https://ghfast.top/',
    'https://ghproxy.net/',
    'https://gh-proxy.com/',
    'https://github.moeyy.xyz/',
  ];

  /// latest.json 的检查源（jsDelivr 仓库文件，国内可达；cdn 主域名常被墙用备用端点）
  static const List<String> _latestJsonUrls = [
    'https://fastly.jsdelivr.net/gh/$_repo@main/hotfix/latest.json',
    'https://gcore.jsdelivr.net/gh/$_repo@main/hotfix/latest.json',
  ];

  static const Duration _apiTimeout = Duration(seconds: 4);
  static const Duration _mirrorTimeout = Duration(seconds: 5);
  static const int _minApkBytes = 1 * 1024 * 1024; // 1MB 完整性下限

  /// 测试钩子：false 时不发起任何网络检查（widget 测试环境用，
  /// 避免真实网络请求在测试结束后留下 pending timer）
  static bool networkChecksEnabled = true;

  PackageInfo? _packageInfo;
  UpdateCheckOutcome? _cachedOutcome;

  /// 从 APK 资产名解析 versionCode：linkgame-1.1.1+3.apk → 3
  static int? parseVersionCodeFromAsset(String name) {
    final m = RegExp(r'\+(\d+)\.apk$').firstMatch(name.toLowerCase());
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  /// 当前应用的 versionCode
  Future<int> currentVersionCode() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return int.tryParse(_packageInfo!.buildNumber) ?? 0;
  }

  /// 当前应用版本名，如 1.1.1
  Future<String> currentVersionName() async {
    _packageInfo ??= await PackageInfo.fromPlatform();
    return _packageInfo!.version;
  }

  /// 查询最新版本；返回结果区分「有更新 / 已最新 / 检查失败」
  Future<UpdateCheckOutcome> checkLatest() async {
    if (kIsWeb || !networkChecksEnabled) return UpdateCheckOutcome.upToDate;

    // 源 1：GitHub API（海外/代理网络下最快最准）
    try {
      final resp = await http.get(
        Uri.parse(_apiLatestUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'link_game-app',
        },
      ).timeout(_apiTimeout);
      if (resp.statusCode == 200) {
        final outcome = await _parseApiPayload(utf8.decode(resp.bodyBytes));
        if (outcome != null) return outcome;
      }
    } catch (e) {
      debugPrint('UpdateService: GitHub API 不可达，走镜像通道 - $e');
    }

    // 源 2：hotfix release 上的 latest.json（镜像多源，国内可达）
    try {
      final meta = await _fetchLatestJsonViaMirrors();
      if (meta != null) {
        return await _evaluateMetadata(meta);
      }
    } catch (e) {
      debugPrint('UpdateService: latest.json 通道失败 - $e');
    }

    return UpdateCheckOutcome.failed;
  }

  /// 解析 GitHub API 响应；响应合法时返回结论，结构异常返回 null（交给下一源）
  Future<UpdateCheckOutcome?> _parseApiPayload(String body) async {
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) return null;

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
      if (code <= current) return UpdateCheckOutcome.upToDate;

      return UpdateCheckOutcome(
        release: RemoteRelease(
          tagName: (data['tag_name'] as String?) ?? '',
          versionName: name.substring(0, name.lastIndexOf('+')).split('-').last,
          versionCode: code,
          apkDownloadUrl: url,
        ),
        succeeded: true,
      );
    }
    return null;
  }

  /// 多源拉取 latest.json（jsDelivr 仓库文件优先，release 资产镜像回退）
  Future<Map<String, dynamic>?> _fetchLatestJsonViaMirrors() async {
    final urls = <String>[
      ..._latestJsonUrls,
      for (final mirror in _downloadMirrors)
        '${mirror}https://github.com/$_repo/releases/download/hotfix/latest.json',
    ];
    for (final url in urls) {
      try {
        final resp = await http.get(Uri.parse(url)).timeout(_mirrorTimeout);
        if (resp.statusCode != 200) continue;
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // 尝试下一个源
      }
    }
    return null;
  }

  /// 依据 latest.json 内容判断是否有更新
  Future<UpdateCheckOutcome> _evaluateMetadata(
    Map<String, dynamic> meta,
  ) async {
    final code = meta['versionCode'];
    final name = meta['versionName'];
    final apkAsset = meta['apkAsset'];
    if (code is! int || name is! String || apkAsset is! String) {
      return UpdateCheckOutcome.failed;
    }

    final current = await currentVersionCode();
    if (code <= current) return UpdateCheckOutcome.upToDate;

    return UpdateCheckOutcome(
      release: RemoteRelease(
        tagName: (meta['tag'] as String?) ?? 'v$name',
        versionName: name,
        versionCode: code,
        apkDownloadUrl:
            'https://github.com/$_repo/releases/download/v$name/$apkAsset',
      ),
      succeeded: true,
    );
  }

  /// 本次运行只检查一次（主菜单横幅用）
  Future<UpdateCheckOutcome> checkOncePerRun() async {
    _cachedOutcome ??= await checkLatest();
    return _cachedOutcome!;
  }

  /// 下载 APK 到临时目录（多源回退，[onProgress] 0.0~1.0），返回本地路径
  Future<String> downloadApk(
    RemoteRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/linkgame-${release.versionName}+${release.versionCode}.apk');
    if (await file.exists()) await file.delete();

    Object? lastError;
    for (final mirror in _downloadMirrors) {
      try {
        final request = http.Request(
            'GET', Uri.parse('$mirror${release.apkDownloadUrl}'));
        final resp = await http.Client()
            .send(request)
            .timeout(const Duration(minutes: 5));
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
