import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:teigi/core/models/conversion_options.dart';

/// Service to rasterize SVG vector images into high-quality raster formats (PNG, JPG, etc.).
class SvgRasterizer {
  const SvgRasterizer();

  /// Check whether the given extension or file is an SVG.
  static bool isSvg(String? extensionOrPath) {
    if (extensionOrPath == null || extensionOrPath.isEmpty) return false;
    final ext = p.extension(extensionOrPath).replaceFirst('.', '').toLowerCase();
    return ext == 'svg' || extensionOrPath.toLowerCase() == 'svg';
  }

  /// Parses SVG width and height from the `<svg>` root tag or its `viewBox`.
  static (double?, double?) parseSvgDimensions(String svgContent) {
    // 1. Check for width and height attributes in <svg ...>
    final svgTagMatch = RegExp(r'<svg\b([^>]*)>', caseSensitive: false).firstMatch(svgContent);
    if (svgTagMatch == null) return (null, null);

    final attrs = svgTagMatch.group(1) ?? '';

    double? parseAttr(String name) {
      final match = RegExp('$name\\s*=\\s*["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(attrs);
      if (match == null) return null;
      final raw = match.group(1)?.trim() ?? '';
      // Strip units like px, pt, mm, cm, in
      final numStr = raw.replaceAll(RegExp(r'[a-zA-Z%]+$'), '').trim();
      return double.tryParse(numStr);
    }

    var w = parseAttr('width');
    var h = parseAttr('height');

    // 2. If missing or invalid, fall back to viewBox
    if (w == null || h == null || w <= 0 || h <= 0) {
      final vbMatch = RegExp(r'viewBox\s*=\s*["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(attrs);
      if (vbMatch != null) {
        final parts = (vbMatch.group(1) ?? '')
            .split(RegExp(r'[\s,]+'))
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.length >= 4) {
          final vbW = double.tryParse(parts[2]);
          final vbH = double.tryParse(parts[3]);
          if (vbW != null && vbW > 0 && vbH != null && vbH > 0) {
            w ??= vbW;
            h ??= vbH;
          }
        }
      }
    }

    return (w, h);
  }

  /// Calculates target dimensions based on SVG intrinsic size and conversion options.
  static (int, int) resolveTargetSize({
    required double? intrinsicWidth,
    required double? intrinsicHeight,
    ConversionOptions? options,
  }) {
    double baseW = intrinsicWidth ?? 1024;
    double baseH = intrinsicHeight ?? 1024;
    if (baseW <= 0) baseW = 1024;
    if (baseH <= 0) baseH = 1024;

    // Check explicit resolution (e.g. "1920x1080")
    if (options?.resolution != null && options!.resolution!.isNotEmpty) {
      final parts = options.resolution!.split('x');
      if (parts.length == 2) {
        final rw = int.tryParse(parts[0]);
        final rh = int.tryParse(parts[1]);
        if (rw != null && rh != null && rw > 0 && rh > 0) {
          return (rw, rh);
        }
      }
    }

    // Check maxResolution constraint (e.g. "1280x720")
    if (options?.maxResolution != null && options!.maxResolution!.isNotEmpty) {
      final parts = options.maxResolution!.split('x');
      if (parts.length == 2) {
        final mw = double.tryParse(parts[0]);
        final mh = double.tryParse(parts[1]);
        if (mw != null && mh != null && mw > 0 && mh > 0) {
          if (baseW > mw || baseH > mh) {
            final scale = (mw / baseW) < (mh / baseH) ? (mw / baseW) : (mh / baseH);
            baseW *= scale;
            baseH *= scale;
          }
        }
      }
    }

    return (baseW.round().clamp(1, 16384), baseH.round().clamp(1, 16384));
  }

  /// Rasterizes SVG file into PNG bytes.
  static Future<List<int>> rasterizeToPngBytes({
    required String svgContent,
    int? targetWidth,
    int? targetHeight,
  }) async {
    final (srcW, srcH) = parseSvgDimensions(svgContent);
    final (outW, outH) = resolveTargetSize(
      intrinsicWidth: targetWidth?.toDouble() ?? srcW,
      intrinsicHeight: targetHeight?.toDouble() ?? srcH,
    );

    final pictureInfo = await vg.loadPicture(SvgStringLoader(svgContent), null);
    final picture = pictureInfo.picture;
    final picSize = pictureInfo.size;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final effectiveSrcW = picSize.width > 0 ? picSize.width : (srcW ?? outW.toDouble());
    final effectiveSrcH = picSize.height > 0 ? picSize.height : (srcH ?? outH.toDouble());

    final scaleX = outW / effectiveSrcW;
    final scaleY = outH / effectiveSrcH;
    canvas.scale(scaleX, scaleY);
    canvas.drawPicture(picture);

    final recorded = recorder.endRecording();
    final image = await recorded.toImage(outW, outH);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    pictureInfo.picture.dispose();
    recorded.dispose();
    image.dispose();

    if (byteData == null) {
      throw StateError('Failed to encode rasterized SVG to PNG byte data');
    }

    return byteData.buffer.asUint8List();
  }

  /// Rasterizes an SVG file to an output file path.
  static Future<void> rasterizeFile({
    required String sourcePath,
    required String outputPath,
    ConversionOptions? options,
  }) async {
    final file = File(sourcePath);
    if (!await file.exists()) {
      throw FileSystemException('Source SVG file not found', sourcePath);
    }

    final content = await file.readAsString();
    final (srcW, srcH) = parseSvgDimensions(content);
    final (outW, outH) = resolveTargetSize(
      intrinsicWidth: srcW,
      intrinsicHeight: srcH,
      options: options,
    );

    final pngBytes = await rasterizeToPngBytes(
      svgContent: content,
      targetWidth: outW,
      targetHeight: outH,
    );

    final outFile = File(outputPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(pngBytes, flush: true);
  }
}
