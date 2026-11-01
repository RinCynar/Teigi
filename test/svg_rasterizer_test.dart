import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/services/svg_rasterizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SvgRasterizer', () {
    test('parses dimensions and viewBox accurately', () {
      const svgWithDims = '<svg width="400px" height="300px" viewBox="0 0 400 300"></svg>';
      final (w1, h1) = SvgRasterizer.parseSvgDimensions(svgWithDims);
      expect(w1, 400.0);
      expect(h1, 300.0);

      const svgViewBoxOnly = '<svg viewBox="0 0 800 600"></svg>';
      final (w2, h2) = SvgRasterizer.parseSvgDimensions(svgViewBoxOnly);
      expect(w2, 800.0);
      expect(h2, 600.0);

      const svgMalformed = '<svg></svg>';
      final (w3, h3) = SvgRasterizer.parseSvgDimensions(svgMalformed);
      expect(w3, isNull);
      expect(h3, isNull);
    });

    test('resolveTargetSize respects explicit resolution and maxResolution', () {
      final (w1, h1) = SvgRasterizer.resolveTargetSize(
        intrinsicWidth: 500,
        intrinsicHeight: 500,
        options: const ConversionOptions(resolution: '1920x1080'),
      );
      expect(w1, 1920);
      expect(h1, 1080);

      final (w2, h2) = SvgRasterizer.resolveTargetSize(
        intrinsicWidth: 2000,
        intrinsicHeight: 1000,
        options: const ConversionOptions(maxResolution: '1000x1000'),
      );
      expect(w2, 1000);
      expect(h2, 500);
    });

    test('rasterizeFile outputs valid PNG with proper header', () async {
      final tempDir = await Directory.systemTemp.createTemp('teigi_svg_test_');
      final inputSvg = File('${tempDir.path}/test_vector.svg');
      final outputPng = File('${tempDir.path}/output_raster.png');

      await inputSvg.writeAsString('''
<svg xmlns="http://www.w3.org/2000/svg" width="200" height="200" viewBox="0 0 200 200">
  <rect width="200" height="200" fill="#39C5BB"/>
  <circle cx="100" cy="100" r="50" fill="#FFFFFF"/>
</svg>
''');

      await SvgRasterizer.rasterizeFile(
        sourcePath: inputSvg.path,
        outputPath: outputPng.path,
      );

      expect(await outputPng.exists(), isTrue);
      final bytes = await outputPng.readAsBytes();
      expect(bytes.length, greaterThan(100));

      // PNG signature: 0x89 0x50 0x4E 0x47 0x0D 0x0A 0x1A 0x0A
      expect(bytes.sublist(0, 8), equals(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])));

      // Cleanup
      await tempDir.delete(recursive: true);
    });
  });
}
