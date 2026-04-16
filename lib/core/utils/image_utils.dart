import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// 영수증 이미지 전처리 — 장변 max 1024px 리사이즈 + JPEG quality 80 인코딩.
///
/// 목적: AI(Codex/Gemini) 요청 시 원본 4K 사진 그대로 보내면 토큰·대역폭 낭비.
/// 보통 영수증은 1024px 이상이어도 OCR 정확도 차이가 거의 없다.
class ImageUtils {
  static const int maxEdgePx = 1024;
  static const int jpegQuality = 80;

  /// 메모리 상에서 리사이즈+JPEG 인코딩하여 byte 반환.
  /// 파일 디스크에 쓰지 않음. AI 호출용 입력으로 바로 사용 가능.
  static Future<Uint8List> resizeToMax1024JpegQ80(File source) async {
    final originalBytes = await source.readAsBytes();
    final originalSize = originalBytes.length;

    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw StateError('이미지 디코드 실패: ${source.path}');
    }

    final w = decoded.width;
    final h = decoded.height;
    final longEdge = w > h ? w : h;

    img.Image processed;
    if (longEdge <= maxEdgePx) {
      processed = decoded;
      debugPrint(
        '[Img] no resize needed: ${w}x$h (long edge $longEdge ≤ $maxEdgePx)',
      );
    } else {
      final scale = maxEdgePx / longEdge;
      final newW = (w * scale).round();
      final newH = (h * scale).round();
      processed = img.copyResize(
        decoded,
        width: newW,
        height: newH,
        interpolation: img.Interpolation.linear,
      );
      debugPrint('[Img] resize: ${w}x$h → ${newW}x$newH');
    }

    final encoded = img.encodeJpg(processed, quality: jpegQuality);
    final out = Uint8List.fromList(encoded);
    final saved = (1 - out.length / originalSize) * 100;
    debugPrint(
      '[Img] encoded JPEG q$jpegQuality: ${originalSize}B → ${out.length}B '
      '(${saved.toStringAsFixed(1)}% saved)',
    );

    return out;
  }

  /// 리사이즈 후 destPath 에 저장하고 File 반환.
  /// 영수증을 앱 내부 documents 디렉토리에 영구 보관할 때 사용.
  static Future<File> resizeAndSave(File source, String destPath) async {
    final bytes = await resizeToMax1024JpegQ80(source);
    final dest = File(destPath);
    await dest.parent.create(recursive: true);
    await dest.writeAsBytes(bytes, flush: true);
    debugPrint('[Img] saved to $destPath (${bytes.length}B)');
    return dest;
  }
}
