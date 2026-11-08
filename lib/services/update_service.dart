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
import '../utils/download_speed_monitor.dart';

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
/// 下载策略（全量 APK 与增量补丁共用）：镜像优先、直连垫底；下载中监测
/// 速率，停滞即断开换下一个源并断点续传（详见 _downloadMirrors 注释）。
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

  /// APK 下载源前缀（拼在 GitHub 资产 URL 前；空字符串 = GitHub 直连）
  ///
  /// 国内 IPv4 无代理网络下，GitHub 直连往往「能连上但被限速到几 KB/s」，
  /// 而公共镜像通常快得多，故镜像优先、直连垫底（海外/代理网络走镜像也不慢）。
  /// 停滞源会自动断开换下一个源并断点续传（见 _streamIdleTimeout），镜像
  /// 存活率波动时增删此列表即可。
  static const List<String> _downloadMirrors = [
    'https://ghfast.top/',
    'https://ghproxy.net/',
    'https://gh-proxy.com/',
    'https://github.moeyy.xyz/',
    '',
  ];

  /// latest.json 的检查源（jsDelivr 仓库文件，国内可达；cdn 主域名常被墙用备用端点）
  static const List<String> _latestJsonUrls = [
    'https://fastly.jsdelivr.net/gh/$_repo@main/hotfix/latest.json',
    'https://gcore.jsdelivr.net/gh/$_repo@main/hotfix/latest.json',
  ];

  static const Duration _apiTimeout = Duration(seconds: 4);
  static const Duration _mirrorTimeout = Duration(seconds: 5);
  static const int _minApkBytes = 1 * 1024 * 1024; // 1MB 完整性下限

  /// 慢速判定：观测窗口内平均速率低于阈值视为停滞，断开换下一个源
  static const Duration _stallWindow = Duration(seconds: 8);
  static const int _stallMinBytesPerSecond = 32 * 1024;

  /// 流内无数据超时：连接冻结（头到了但数据完全不来）时兜底换源，
  /// 与慢速判定互补（后者只覆盖「还在慢慢来」的情况）
  static const Duration _streamIdleTimeout = Duration(seconds: 20);

  /// 单源请求超时（拿到响应头的期限；之后的慢速/冻结由流内监测接管）
  static const Duration _requestTimeout = Duration(minutes: 3);

  /// 测试钩子：false 时不发起任何网络检查（widget 测试环境用，
  /// 避免真实网络请求在测试结束后留下 pending timer）
  static bool networkChecksEnabled = true;

  /// 测试钩子：替换网络客户端来源（默认每次新建）；客户端用毕由服务关闭
  @visibleForTesting
  static http.Client Function()? clientFactory;

  /// 测试钩子：覆盖当前时间（慢速监视采样用）
  @visibleForTesting
  static DateTime Function()? clockOverride;

  /// 测试钩子：覆盖下载落盘目录（默认 getTemporaryDirectory()）
  @visibleForTesting
  static Future<Directory> Function()? tempDirectoryResolver;

  http.Client _newClient() => clientFactory?.call() ?? http.Client();

  DateTime _now() => clockOverride?.call() ?? DateTime.now();

  Future<Directory> _downloadDir() async {
    final resolver = tempDirectoryResolver;
    if (resolver != null) return resolver();
    return getTemporaryDirectory();
  }

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
  /// 顺序：release 资产镜像（即时新鲜，直连垫底）→ jsDelivr（可达性最好但有缓存延迟）兜底
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

    // 下载补丁（多源回退 + 断点续传），进度映射到 0~0.9
    final dir = await _downloadDir();
    final patchFile = File('${dir.path}/${patch.asset}');

    final baseUrl = release.apkDownloadUrl
        .substring(0, release.apkDownloadUrl.lastIndexOf('/') + 1);
    await _downloadFromMirrors(
      url: '$baseUrl${patch.asset}',
      file: patchFile,
      totalHint: patch.size,
      validateSize: (length) => length == patch.size,
      onProgress: onProgress == null
          ? null
          : (fraction) => onProgress((fraction * 0.9).clamp(0.0, 0.9)),
    );

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
    final dir = await _downloadDir();
    final file = File(
        '${dir.path}/linkgame-${release.versionName}+${release.versionCode}.apk');
    await _downloadFromMirrors(
      url: release.apkDownloadUrl,
      file: file,
      totalHint: null,
      validateSize: (length) => length >= _minApkBytes,
      onProgress: onProgress,
    );
    return file.path;
  }

  /// 多源流式下载：镜像优先、直连垫底；任一源停滞/报错即换下一个源，
  /// 已落盘的前缀通过 HTTP Range 断点续传（源不支持时从头重下）。
  ///
  /// [url] 完整资源 URL；[totalHint] 已知总字节数（未知传 null，进度降级）；
  /// [validateSize] 单源完成后按落盘字节数判定完整性，不完整视同失败换源。
  /// [onProgress] 收到 0.0~1.0 的整体进度。全部源失败抛 StateError。
  ///
  /// 失败/停滞时保留部分文件：同版本重试可从断点继续，不必推倒重来。
  Future<void> _downloadFromMirrors({
    required String url,
    required File file,
    required int? totalHint,
    required bool Function(int fileLength) validateSize,
    void Function(double fraction)? onProgress,
  }) async {
    Object? lastError;
    for (var i = 0; i < _downloadMirrors.length; i++) {
      // 最后一个源（直连）没有可切换的退路：不再因停滞中断，慢也拉完
      final isLastSource = i == _downloadMirrors.length - 1;

      var resumeFrom = await file.exists() ? await file.length() : 0;
      if (totalHint != null && resumeFrom >= totalHint) {
        // 残留文件已达预期大小（完整性校验失败过的脏数据）：丢弃重来
        await file.delete();
        resumeFrom = 0;
      }
      try {
        await _downloadOnce(
          uri: Uri.parse('${_downloadMirrors[i]}$url'),
          file: file,
          resumeFrom: resumeFrom,
          totalHint: totalHint,
          abortOnStall: !isLastSource,
          onProgress: onProgress,
        );
        if (validateSize(await file.length())) return;
        lastError = '下载不完整（${await file.length()} 字节）';
      } catch (e) {
        lastError = e;
      }
    }
    throw StateError('所有下载源均失败: $lastError');
  }

  /// 单源一次下载尝试（带断点续传 + 慢速停滞中断）
  ///
  /// 从 [resumeFrom] 偏移续传；服务器不支持 Range（返回 200）时丢弃旧前缀
  /// 从头写。抛出异常表示本次尝试失败，已落盘前缀保留供下一个源续传。
  Future<void> _downloadOnce({
    required Uri uri,
    required File file,
    required int resumeFrom,
    required int? totalHint,
    required bool abortOnStall,
    void Function(double fraction)? onProgress,
  }) async {
    final client = _newClient();
    try {
      var offset = resumeFrom;
      http.StreamedResponse resp;
      while (true) {
        final request = http.Request('GET', uri);
        if (offset > 0) {
          request.headers['Range'] = 'bytes=$offset-';
        }
        final sent = await client.send(request).timeout(_requestTimeout);
        if (sent.statusCode == 416 && offset > 0) {
          // 残留前缀比远端还大（损坏/错版）：丢弃后从头下
          if (await file.exists()) await file.delete();
          offset = 0;
          continue;
        }
        resp = sent;
        break;
      }

      var base = offset;
      int? total = totalHint;
      if (resp.statusCode == 206) {
        final start = _contentRangeStart(resp.headers['content-range']);
        if (start != base) {
          // 服务器给的续传起点对不上：宁可换源也不写坏文件
          throw HttpException('Content-Range 起始偏移与断点不符', uri: uri);
        }
        final len = resp.contentLength;
        if (len != null) total = base + len;
      } else if (resp.statusCode == 200) {
        // 未接受 Range（或不带 Range）：从头写
        base = 0;
        total = resp.contentLength ?? totalHint;
        if (await file.exists()) await file.delete();
      } else {
        throw HttpException('HTTP ${resp.statusCode}', uri: uri);
      }

      final monitor = DownloadSpeedMonitor(
        window: _stallWindow,
        minBytesPerSecond: _stallMinBytesPerSecond,
        now: _now,
      );
      final sink =
          file.openWrite(mode: base > 0 ? FileMode.append : FileMode.write);
      var closed = false;
      try {
        await for (final chunk in resp.stream.timeout(_streamIdleTimeout)) {
          base += chunk.length;
          monitor.sample(base);
          if (abortOnStall && monitor.isStalled) {
            throw const _StalledDownloadException();
          }
          sink.add(chunk);
          if (total != null && total > 0 && onProgress != null) {
            onProgress((base / total).clamp(0.0, 1.0));
          }
        }
        await sink.flush();
        closed = true;
        await sink.close();
      } catch (e) {
        // 尽量把已收到的前缀落盘，供下一个源断点续传
        if (!closed) {
          try {
            await sink.flush();
          } catch (_) {}
          await sink.close();
        }
        rethrow;
      }
    } finally {
      client.close();
    }
  }

  /// 从 Content-Range（如 "bytes 500-999/1234"）解析起始偏移；格式异常返回 null
  static int? _contentRangeStart(String? header) {
    if (header == null) return null;
    final m = RegExp(r'^bytes\s+(\d+)-').firstMatch(header.trim());
    return m != null ? int.tryParse(m.group(1)!) : null;
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

/// 下载速率长期低于阈值（判定停滞），应切换下一个下载源
class _StalledDownloadException implements Exception {
  const _StalledDownloadException();

  @override
  String toString() => '下载停滞（速率过低）';
}
