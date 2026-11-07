import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/bspatch.dart';

/// 增量更新补丁描述（bsdiff 差分包）
class PatchInfo {
  final int fromCode;

  /// "from" 版本 APK 的 SHA-256（必须与设备上已安装包逐字节一致才能套用）
  final String fromSha256;
  final String asset;
  final int size;
  final String sha256;
  final int outSize;
  final String outSha256;

  const PatchInfo({
    required this.fromCode,
    required this.fromSha256,
    required this.asset,
    required this.size,
    required this.sha256,
    required this.outSize,
    required this.outSha256,
  });

  static PatchInfo? fromJson(Map<String, dynamic> json) {
    final fromCode = json['fromCode'];
    final fromSha256 = json['fromSha256'];
    final asset = json['asset'];
    final size = json['size'];
    final sha256 = json['sha256'];
    final outSize = json['outSize'];
    final outSha256 = json['outSha256'];
    if (fromCode is! int ||
        fromSha256 is! String ||
        asset is! String ||
        size is! int ||
        sha256 is! String ||
        outSize is! int ||
        outSha256 is! String) {
      return null;
    }
    return PatchInfo(
      fromCode: fromCode,
      fromSha256: fromSha256,
      asset: asset,
      size: size,
      sha256: sha256,
      outSize: outSize,
      outSha256: outSha256,
    );
  }
}

/// GitHub Release 上的远端版本信息
class RemoteRelease {
  final String tagName;
  final String versionName;
  final int versionCode;

  /// APK 资产的 GitHub 下载地址（下载时按需拼镜像前缀）
  final String apkDownloadUrl;

  /// 可用的增量补丁（latest.json 通道才有；API 通道为空，走全量）
  final List<PatchInfo> patches;

  const RemoteRelease({
    required this.tagName,
    required this.versionName,
    required this.versionCode,
    required this.apkDownloadUrl,
    this.patches = const [],
  });

  /// 找到适用于当前安装版本的补丁
  PatchInfo? patchFor(int currentVersionCode) {
    for (final p in patches) {
      if (p.fromCode == currentVersionCode) return p;
    }
    return null;
  }
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

  /// 多源拉取 latest.json
  /// 顺序：release 资产镜像（即时新鲜）优先，jsDelivr（可达性最好但有缓存延迟）兜底
  Future<Map<String, dynamic>?> _fetchLatestJsonViaMirrors() async {
    final urls = <String>[
      for (final mirror in _downloadMirrors)
        '${mirror}https://github.com/$_repo/releases/download/hotfix/latest.json',
      ..._latestJsonUrls,
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

    // 解析增量补丁列表（可选字段）
    final patches = <PatchInfo>[];
    final rawPatches = meta['patches'];
    if (rawPatches is List) {
      for (final raw in rawPatches) {
        if (raw is Map<String, dynamic>) {
          final p = PatchInfo.fromJson(raw);
          if (p != null) patches.add(p);
        }
      }
    }

    return UpdateCheckOutcome(
      release: RemoteRelease(
        tagName: (meta['tag'] as String?) ?? 'v$name',
        versionName: name,
        versionCode: code,
        apkDownloadUrl:
            'https://github.com/$_repo/releases/download/v$name/$apkAsset',
        patches: patches,
      ),
      succeeded: true,
    );
  }

  /// 本次运行只检查一次（主菜单横幅用）
  Future<UpdateCheckOutcome> checkOncePerRun() async {
    _cachedOutcome ??= await checkLatest();
    return _cachedOutcome!;
  }

  /// 更新下载入口：优先增量补丁（体积小），任何失败自动回退全量 APK
  Future<String> downloadUpdate(
    RemoteRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    final current = await currentVersionCode();
    final patch = release.patchFor(current);
    if (patch != null) {
      try {
        return await _downloadViaPatch(release, patch, onProgress: onProgress);
      } catch (e) {
        debugPrint('UpdateService: 增量更新失败，回退全量下载 - $e');
      }
    }
    return downloadApk(release, onProgress: onProgress);
  }

  static const MethodChannel _appInfoChannel =
      MethodChannel('linkgame/app_info');

  /// 已安装 APK 的文件路径（差分基准），获取失败返回 null
  Future<String?> _installedApkPath() async {
    try {
      return await _appInfoChannel.invokeMethod<String>('getInstalledApkPath');
    } catch (_) {
      return null;
    }
  }

  Future<String> _sha256OfFile(String path) async {
    final digest = await crypto.sha256.bind(File(path).openRead()).first;
    return digest.toString();
  }

  /// 增量路径：校验已装包哈希 → 下载补丁 → 重建 APK → 校验新包哈希
  Future<String> _downloadViaPatch(
    RemoteRelease release,
    PatchInfo patch, {
    void Function(double progress)? onProgress,
  }) async {
    final installed = await _installedApkPath();
    if (installed == null) {
      throw StateError('无法获取已安装 APK 路径');
    }
    final oldHash = await _sha256OfFile(installed);
    if (oldHash != patch.fromSha256) {
      throw StateError('已安装包哈希不匹配（$oldHash）');
    }

    // 下载补丁（多源回退），进度映射到 0~0.9
    final dir = await getTemporaryDirectory();
    final patchFile = File('${dir.path}/${patch.asset}');
    if (await patchFile.exists()) await patchFile.delete();

    final baseUrl =
        release.apkDownloadUrl.substring(0, release.apkDownloadUrl.lastIndexOf('/') + 1);
    Object? lastError;
    var downloaded = false;
    for (final mirror in _downloadMirrors) {
      try {
        final resp = await http.Client()
            .send(http.Request('GET', Uri.parse('$mirror$baseUrl${patch.asset}')))
            .timeout(const Duration(minutes: 3));
        if (resp.statusCode != 200) {
          lastError = 'HTTP ${resp.statusCode}';
          continue;
        }
        final total = resp.contentLength ?? patch.size;
        int received = 0;
        final sink = patchFile.openWrite();
        try {
          await for (final chunk in resp.stream) {
            received += chunk.length;
            sink.add(chunk);
            if (total > 0 && onProgress != null) {
              onProgress(((received / total) * 0.9).clamp(0.0, 0.9));
            }
          }
          await sink.flush();
          await sink.close();
        } catch (_) {
          await sink.close();
          rethrow;
        }
        downloaded = true;
        break;
      } catch (e) {
        lastError = e;
        if (await patchFile.exists()) await patchFile.delete();
      }
    }
    if (!downloaded) throw StateError('补丁所有下载源均失败: $lastError');

    // 补丁完整性
    if (await patchFile.length() != patch.size) {
      throw StateError('补丁大小不符');
    }
    final patchHash = await _sha256OfFile(patchFile.path);
    if (patchHash != patch.sha256) {
      throw StateError('补丁哈希不符');
    }

    // 重建：进度映射到 0.9~1.0
    onProgress?.call(0.92);
    final oldData = await File(installed).readAsBytes();
    final patchData = await patchFile.readAsBytes();
    final newApk = Bspatch.patch(oldData, patchData);
    if (newApk.length != patch.outSize) {
      throw StateError('重建后大小不符（${newApk.length}）');
    }
    final outHash = crypto.sha256.convert(newApk).toString();
    if (outHash != patch.outSha256) {
      throw StateError('重建后哈希不符');
    }
    onProgress?.call(0.98);

    final outFile =
        File('${dir.path}/linkgame-${release.versionName}+${release.versionCode}.apk');
    if (await outFile.exists()) await outFile.delete();
    await outFile.writeAsBytes(newApk, flush: true);
    await patchFile.delete();
    onProgress?.call(1.0);
    return outFile.path;
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
