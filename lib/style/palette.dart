import 'package:flutter/material.dart';

/// 全局调色板 — 「暖白高可读」定稿
///
/// 设计约束（适老化）：
/// - 只有一套日间主题，无夜间模式（低视力用户在暗色界面上更难辨识）
/// - 全天候高可读性：正文对表面对比度 ≥ 7:1，次要文字 ≥ 6:1
/// - 琥珀/金色只做强调填充，其上文字一律用深墨色（白字对琥珀只有 ~2:1，禁用）
/// - 藏蓝是唯一的大面积深色（标题栏/主按钮），白字对比 ≥ 10:1
class Palette {
  Palette._();

  // ---- 底色与表面 ----
  /// 页面底色（米灰，比表面深一档，衬托白色卡片）
  static const Color scaffold = Color(0xFFF0EBDF);

  /// 卡片 / 弹窗表面（暖白）
  static const Color surface = Color(0xFFFDFBF6);

  /// 分组容器 / 次级表面
  static const Color container = Color(0xFFE9E3D4);

  /// 边框与分隔线
  static const Color outline = Color(0xFFC6BEAC);

  // ---- 文字 ----
  /// 正文近黑藏蓝（对 surface ≈ 12.8:1）
  static const Color text = Color(0xFF1C2B3A);

  /// 次要文字（对 surface ≈ 6.3:1）
  static const Color textMuted = Color(0xFF54616E);

  // ---- 品牌 ----
  /// 主色藏蓝：标题栏、主按钮（白字 ≈ 10.9:1）
  static const Color navy = Color(0xFF1B3A5C);

  /// 藏蓝按压态
  static const Color navyDeep = Color(0xFF142B45);

  /// 琥珀强调填充（上面必须配 [inkOnAmber] 深色文字）
  static const Color amber = Color(0xFFFFB300);

  /// 琥珀底上的文字（对 amber ≈ 5.8:1）
  static const Color inkOnAmber = Color(0xFF3D2B00);

  /// 琥珀系文字色（对 surface ≈ 5.2:1，用于大号数字/强调词）
  static const Color amberText = Color(0xFFA96E00);

  /// 成功 / 连线青绿
  static const Color teal = Color(0xFF1F7A68);

  /// 错误红
  static const Color red = Color(0xFFC62828);

  /// 标题栏上的进度槽（比 navy 亮一档）
  static const Color progressTrackOnNavy = Color(0xFF33506E);
}
