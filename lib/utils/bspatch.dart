import 'dart:typed_data';

import 'package:archive/archive.dart';

/// 纯 Dart 实现的 bspatch，用于应用内增量更新
///
/// 容器为标准 BSDIFF40（bsdiff4 工具直接产出，无需转换）：
/// ```
/// 偏移 0  : magic "BSDIFF40"
/// 偏移 8  : int64 LE ctrl 流的压缩字节数
/// 偏移 16 : int64 LE diff 流的压缩字节数
/// 偏移 24 : int64 LE 重建后文件总长（解压后）
/// 偏移 32 : bzip2(ctrl) | bzip2(diff) | bzip2(extra) 三段流首尾相连
/// ```
/// 注意两个易错点：
/// - 头部三个值是【压缩后】长度，不能拿去和解压输出比对
/// - 控制元组用 offtin 编码（大端 + 符号幅值），与头部的小端不同
///
/// 服务端用 bsdiff 对新旧 APK 做字节级差分，客户端把「已安装 APK + 补丁」
/// 重建为「新 APK 的逐字节拷贝」——输出与官方发布的新 APK 完全一致，
/// APK v2 签名原样保留，可直接安装。
class Bspatch {
  Bspatch._();

  /// 对 [oldData] 应用 [patchData]，返回重建出的新文件字节。
  ///
  /// 补丁不合法时抛 [FormatException]；调用方（UpdateService）还会对结果
  /// 做 SHA-256 校验兜底，任何异常都回退全量下载。
  static Uint8List patch(Uint8List oldData, Uint8List patchData) {
    if (patchData.length < 32) {
      throw const FormatException('patch too small');
    }
    final magic = String.fromCharCodes(patchData.sublist(0, 8));
    if (magic != 'BSDIFF40') {
      throw FormatException('bad magic: $magic');
    }

    final ctrlComp = _le64(patchData, 8);
    final diffComp = _le64(patchData, 16);
    final newLen = _le64(patchData, 24);
    if (ctrlComp < 0 || diffComp < 0 || newLen < 0) {
      throw const FormatException('negative length in header');
    }
    if (newLen > 512 * 1024 * 1024) {
      throw const FormatException('new size too large');
    }
    if (32 + ctrlComp + diffComp > patchData.length) {
      throw const FormatException('header lengths exceed patch size');
    }

    // 按头部给出的压缩长度精确切片，每片恰好一个 bzip2 流
    var offset = 32;
    final ctrl =
        BZip2Decoder().decodeBytes(patchData.sublist(offset, offset + ctrlComp));
    offset += ctrlComp;
    final diff =
        BZip2Decoder().decodeBytes(patchData.sublist(offset, offset + diffComp));
    offset += diffComp;
    final extra = BZip2Decoder().decodeBytes(patchData.sublist(offset));

    final newOut = Uint8List(newLen);
    int oldpos = 0, newpos = 0, cpos = 0, dpos = 0, epos = 0;

    while (newpos < newLen) {
      if (cpos + 24 > ctrl.length) {
        throw const FormatException('control stream exhausted');
      }
      final add = _offtin(ctrl, cpos);
      final insert = _offtin(ctrl, cpos + 8);
      final seek = _offtin(ctrl, cpos + 16);
      cpos += 24;

      // 1) diff 段：old + diff 逐字节相加
      if (add < 0 || newpos + add > newLen || oldpos + add > oldData.length) {
        throw const FormatException('diff segment out of range');
      }
      for (int i = 0; i < add; i++) {
        newOut[newpos + i] = (oldData[oldpos + i] + diff[dpos + i]) & 0xff;
      }
      newpos += add;
      oldpos += add;
      dpos += add;

      // 2) extra 段：逐字节原样拷贝
      if (insert < 0 ||
          newpos + insert > newLen ||
          epos + insert > extra.length) {
        throw const FormatException('extra segment out of range');
      }
      newOut.setRange(newpos, newpos + insert, extra, epos);
      newpos += insert;
      epos += insert;

      // 3) 旧文件指针按有符号偏移移动
      oldpos += seek;
      if (oldpos < 0 || oldpos > oldData.length) {
        throw const FormatException('old file seek out of range');
      }
    }

    return newOut;
  }

  /// int64 小端有符号（头部字段）
  static int _le64(Uint8List b, int offset) {
    return b[offset] |
        (b[offset + 1] << 8) |
        (b[offset + 2] << 16) |
        (b[offset + 3] << 24) |
        (b[offset + 4] << 32) |
        (b[offset + 5] << 40) |
        (b[offset + 6] << 48) |
        (b[offset + 7] << 56);
  }

  /// bsdiff 控制元组的 offtin：大端 64 位 + 符号幅值编码（最高字节最高位为符号位）
  static int _offtin(Uint8List b, int offset) {
    int y = b[offset + 7] & 0x7f;
    for (int i = 6; i >= 0; i--) {
      y = (y << 8) | b[offset + i];
    }
    if ((b[offset + 7] & 0x80) != 0) y = -(y + 1);
    return y;
  }
}
