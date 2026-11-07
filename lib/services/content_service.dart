import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 内容热更服务
///
/// 台词、提示文案、语速默认值等"内容层"数据支持不重装 APK 就远程更新：
/// 1. 启动时从 SharedPreferences 加载上次缓存的远端内容（如有）
/// 2. 异步检查发布在 GitHub Releases 的 hotfix-manifest，rev 更大则下载新内容
/// 3. 校验通过后应用并缓存；任何网络/校验失败都静默回退到内置默认值
///
/// 内容源（多源回退，按顺序尝试）：
/// 仓库 tag `hotfix` 上的 release 固定挂载 hotfix-manifest.json / hotfix-content.json，
/// 由 scripts/publish-hotfix.sh 发布；镜像前缀不可用时可随时调整此列表。
class ContentService {
  ContentService._();

  static final ContentService _instance = ContentService._();
  static ContentService get instance => _instance;

  // ---- 内置默认值（代码基线）----

  static const List<String> defaultPraisePhrases = [
    '太厉害了',
    '真棒',
    '选对了',
    '好样的',
    '真不错',
    '继续加油',
    '连对了',
    '又消掉一对',
  ];
  static const String defaultHintMessage = '提示：找到相同的图案';
  static const String defaultNoPairMessage = '没有可消除的配对，自动重新排列';
  static const double defaultTtsRate = 0.4;

  // ---- 远端内容源（按顺序回退）----
  // release 资产镜像（即时新鲜）优先；jsDelivr 走仓库文件（可达性好但有
  // 最多 12h 的边缘缓存延迟，仅兜底；cdn 主域名在国内常被墙，用备用端点）

  static const String _repo = 'mario841859784/linkgame';
  static const List<String> _contentBaseUrls = [
    'https://github.com/$_repo/releases/download/hotfix',
    'https://ghfast.top/https://github.com/$_repo/releases/download/hotfix',
    'https://ghproxy.net/https://github.com/$_repo/releases/download/hotfix',
    'https://gh-proxy.com/https://github.com/$_repo/releases/download/hotfix',
    'https://fastly.jsdelivr.net/gh/$_repo@main/hotfix',
    'https://gcore.jsdelivr.net/gh/$_repo@main/hotfix',
  ];

  static const String _prefsKeyContent = 'hotfix_content';
  static const Duration _perSourceTimeout = Duration(seconds: 5);

  // ---- 当前生效内容 ----

  List<String> _praisePhrases = defaultPraisePhrases;
  String _hintMessage = defaultHintMessage;
  String _noPairMessage = defaultNoPairMessage;
  double _ttsRateDefault = defaultTtsRate;
  int _appliedRev = 0;

  List<String> get praisePhrases => List.unmodifiable(_praisePhrases);
  String get hintMessage => _hintMessage;
  String get noPairMessage => _noPairMessage;
  double get ttsRateDefault => _ttsRateDefault;
  int get appliedRev => _appliedRev;

  /// 应用前校验，返回清洗后的内容；不合法返回 null（拒绝整个文件，fail-closed）
  static Map<String, dynamic>? validateContent(Map<String, dynamic> raw) {
    final rev = raw['rev'];
    if (rev is! int || rev < 0) return null;

    final phrasesRaw = raw['praisePhrases'];
    if (phrasesRaw is! List) return null;
    final phrases = phrasesRaw
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length <= 30)
        .toList();
    if (phrases.length < 3 || phrases.length > 50) return null;

    final messagesRaw = raw['messages'];
    if (messagesRaw is! Map) return null;
    final hint = messagesRaw['hint'];
    final noPair = messagesRaw['noPairShuffle'];
    if (hint is! String || hint.trim().isEmpty || hint.length > 50) return null;
    if (noPair is! String || noPair.trim().isEmpty || noPair.length > 50) {
      return null;
    }

    final rate = raw['ttsRateDefault'];
    if (rate is! num || rate < 0.2 || rate > 0.7) return null;

    return <String, dynamic>{
      'rev': rev,
      'praisePhrases': phrases,
      'messages': <String, String>{
        'hint': hint.trim(),
        'noPairShuffle': noPair.trim(),
      },
      'ttsRateDefault': rate.toDouble(),
    };
  }

  /// 应用一份已校验的内容到内存
  bool applyContent(Map<String, dynamic> content) {
    final validated = validateContent(content);
    if (validated == null) return false;

    _appliedRev = validated['rev'] as int;
    _praisePhrases = (validated['praisePhrases'] as List).cast<String>();
    final messages = validated['messages'] as Map<String, String>;
    _hintMessage = messages['hint']!;
    _noPairMessage = messages['noPairShuffle']!;
    _ttsRateDefault = validated['ttsRateDefault'] as double;
    return true;
  }

  /// 启动时加载上次缓存的远端内容（同步内存，之后设置服务才能取到默认语速）
  Future<void> loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKeyContent);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        applyContent(decoded);
      }
    } catch (e) {
      debugPrint('ContentService: 加载缓存内容失败 - $e');
    }
  }

  /// 检查远端更新：manifest rev 更大才下载内容，全部静默失败
  Future<void> checkForUpdates() async {
    if (kIsWeb) return; // Web 下不做热更
    try {
      final manifest = await _fetchJson('hotfix-manifest.json');
      if (manifest == null) return;
      final remoteRev = manifest['rev'];
      if (remoteRev is! int || remoteRev <= _appliedRev) return;

      final contentName =
          (manifest['content'] as String?) ?? 'hotfix-content.json';
      final content = await _fetchJson(contentName);
      if (content == null) return;

      if (applyContent(content)) {
        await _saveCached(content);
        debugPrint('ContentService: 内容已热更到 r$_appliedRev');
      }
    } catch (e) {
      debugPrint('ContentService: 检查更新失败（已忽略）- $e');
    }
  }

  /// 依次尝试各内容源，全部失败返回 null
  Future<Map<String, dynamic>?> _fetchJson(String fileName) async {
    for (final base in _contentBaseUrls) {
      try {
        final resp = await http
            .get(Uri.parse('$base/$fileName'))
            .timeout(_perSourceTimeout);
        if (resp.statusCode != 200) continue;
        final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        // 尝试下一个源
      }
    }
    return null;
  }

  Future<void> _saveCached(Map<String, dynamic> content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyContent, jsonEncode(content));
    } catch (e) {
      debugPrint('ContentService: 缓存内容失败 - $e');
    }
  }
}
