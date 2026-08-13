import 'package:flutter_test/flutter_test.dart';

import 'package:teigi/core/ffmpeg/progress_parser.dart';

void main() {
  group('ProgressParser', () {
    test('解析 Duration 行', () {
      final parser = ProgressParser();
      final d = parser.parseDurationLine('  Duration: 00:01:23.45, start: 0.000000, bitrate: 1000 kb/s');
      expect(d, const Duration(minutes: 1, seconds: 23, milliseconds: 450));
      expect(parser.totalDuration, d);
    });

    test('解析进度行 time/speed', () {
      final parser = ProgressParser();
      parser.parseDurationLine('  Duration: 00:01:00.00, start: 0.000000');
      final update = parser.parseProgressLine(
        'frame=  123 fps= 60 q=28.0 size=     512KiB '
        'time=00:00:30.00 bitrate= 205.6kbits/s speed=2.05x',
      );
      expect(update, isNotNull);
      expect(update!.elapsed, const Duration(seconds: 30));
      expect(update.speed, closeTo(2.05, 0.001));
      expect(update.progress, closeTo(0.5, 0.001));
    });

    test('无法解析非进度行返回 null', () {
      final parser = ProgressParser();
      expect(
        parser.parseProgressLine('  libx264 @ 0000021c8bd3d780'),
        isNull,
      );
    });

    test('解析输出路径行', () {
      final parser = ProgressParser();
      final path = parser.parseOutputPath(
        "  Output #0, mp4, to 'C:/out/my video.mp4':",
      );
      expect(path, 'C:/out/my video.mp4');
    });

    test('时长中的毫秒小数位补全', () {
      final parser = ProgressParser();
      final d = parser.parseDurationLine('Duration: 00:00:10.5');
      expect(d, const Duration(seconds: 10, milliseconds: 500));
    });
  });

  group('decodeChunkLines', () {
    test('按回车/换行切分', () {
      const chunk = 'frame=1 time=00:00:01.00 speed=1x\r\n'
          'frame=2 time=00:00:02.00 speed=1x\r';
      final lines = decodeChunkLines(chunk.codeUnits);
      // 切分结果中包含空串，过滤后应为 2 个有效行。
      final nonEmpty = lines.where((l) => l.isNotEmpty).toList();
      expect(nonEmpty, hasLength(2));
    });
  });
}
