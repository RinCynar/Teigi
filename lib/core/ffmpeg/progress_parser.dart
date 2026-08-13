import 'dart:convert';

/// 解析 ffmpeg stderr 输出中的进度信息。
///
/// ffmpeg 的进度信息格式（默认每 0.5s 输出一次，用 \r 刷新）：
/// ```
/// frame=  123 fps= 60 q=28.0 size=     512KiB time=00:00:02.04 bitrate= 205.6kbits/s speed=2.05x
/// ```
class ProgressParser {
  /// 匹配进度行中的关键字段。
  static final RegExp _timePattern = RegExp(r'time=(\d+):(\d+):([\d.]+)');
  static final RegExp _speedPattern = RegExp(r'speed=([\d.]+)x');
  static final RegExp _durationPattern =
      RegExp(r'Duration:\s*(\d+):(\d+):([\d.]+)');

  /// 匹配输出文件行，用于确定实际输出路径。
  /// ffmpeg 实际格式：`Output #0, mp4, to 'C:/out/a.mp4':`
  static final RegExp _outputPattern = RegExp(
    r"Output #0,.*?to\s+'(.+)':",
  );

  /// 总时长（毫秒）。由 [parseDurationLine] 预先设置。
  Duration? totalDuration;

  /// 解析 `Duration: 00:01:23.45` 行，返回总时长并缓存。
  Duration? parseDurationLine(String line) {
    final m = _durationPattern.firstMatch(line);
    if (m != null) {
      final d = _toDuration(m.group(1)!, m.group(2)!, m.group(3)!);
      totalDuration = d;
      return d;
    }
    return null;
  }

  /// 解析一行进度输出。返回 [ProgressUpdate]，无法解析时返回 null。
  ProgressUpdate? parseProgressLine(String line) {
    final timeMatch = _timePattern.firstMatch(line);
    if (timeMatch == null) return null;

    final elapsed = _toDuration(
      timeMatch.group(1)!,
      timeMatch.group(2)!,
      timeMatch.group(3)!,
    );

    final speedMatch = _speedPattern.firstMatch(line);
    final speed = speedMatch != null ? double.tryParse(speedMatch.group(1)!) : null;

    final total = totalDuration;
    double? progress;
    if (total != null && total.inMilliseconds > 0) {
      progress = (elapsed.inMilliseconds / total.inMilliseconds)
          .clamp(0.0, 1.0);
    }

    return ProgressUpdate(
      elapsed: elapsed,
      speed: speed,
      progress: progress,
    );
  }

  /// 从 `Output #0, mp4, to '...':` 行提取输出路径。
  String? parseOutputPath(String line) {
    if (!line.trimLeft().startsWith('Output #0')) return null;
    final m = _outputPattern.firstMatch(line);
    if (m == null) return null;
    return _cleanOutputPath(m.group(1)!.trim());
  }
  static String _cleanOutputPath(String raw) {
    var path = raw;
    if (path.startsWith("'") && path.endsWith("'")) {
      path = path.substring(1, path.length - 1);
    }
    return path.replaceAll(RegExp(r"\\'"), "'");
  }

  Duration _toDuration(String h, String m, String s) {
    final parts = s.split('.');
    final seconds = int.parse(parts[0]);
    final millis = parts.length > 1 ? _parseMillis(parts[1]) : 0;
    return Duration(
      hours: int.parse(h),
      minutes: int.parse(m),
      seconds: seconds,
      milliseconds: millis,
    );
  }

  int _parseMillis(String frac) {
    final padded = frac.padRight(3, '0');
    return int.parse(padded.substring(0, 3));
  }
}

/// 一次进度更新的结果。
class ProgressUpdate {
  final Duration elapsed;
  final double? speed;
  final double? progress;

  const ProgressUpdate({
    required this.elapsed,
    this.speed,
    this.progress,
  });

  @override
  String toString() =>
      'ProgressUpdate(elapsed: $elapsed, speed: $speed, progress: $progress)';
}

/// 解析 ffmpeg 输出的便捷函数（供流式读取使用）。
List<String> decodeChunkLines(List<int> chunk) {
  final text = utf8.decode(chunk, allowMalformed: true);
  // ffmpeg 用 \r 刷新同一行，这里统一拆分为行。
  return text.split(RegExp(r'[\r\n]+'));
}
