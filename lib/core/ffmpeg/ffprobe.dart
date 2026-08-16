import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:teigi/core/domain/media_info.dart';
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/domain/media_type_infer.dart';

/// Parses `ffprobe -print_format json` output. UI must not call Process.
class FfprobeParser {
  const FfprobeParser();

  MediaInfo parseJson(String raw, {required String path}) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return MediaInfo(path: path, inferredType: inferMediaType(_ext(path)));
    }

    final format = decoded['format'] as Map<String, dynamic>? ?? const {};
    final streamsRaw = decoded['streams'] as List<dynamic>? ?? const [];

    final streams = <MediaStream>[
      for (final item in streamsRaw)
        if (item is Map<String, dynamic>) _parseStream(item),
    ];

    final durationSec = double.tryParse('${format['duration'] ?? ''}');
    final size = int.tryParse('${format['size'] ?? ''}');
    final bitrate = int.tryParse('${format['bit_rate'] ?? ''}');

    var inferred = inferMediaType(_ext(path));
    if (inferred == MediaType.unknown) {
      if (streams.any((s) => s is VideoStream)) {
        inferred = MediaType.video;
      } else if (streams.any((s) => s is AudioStream)) {
        inferred = MediaType.audio;
      } else if (streams.any((s) => s is SubtitleStream)) {
        inferred = MediaType.subtitle;
      }
    }

    return MediaInfo(
      path: path,
      format: format['format_name'] as String?,
      duration: durationSec == null
          ? null
          : Duration(milliseconds: (durationSec * 1000).round()),
      sizeBytes: size,
      bitrate: bitrate,
      streams: streams,
      inferredType: inferred,
      probed: true,
    );
  }

  MediaStream _parseStream(Map<String, dynamic> json) {
    final index = json['index'] as int? ?? 0;
    final codec = json['codec_name'] as String?;
    final language = (json['tags'] as Map<String, dynamic>?)?['language']
        as String?;
    final title = (json['tags'] as Map<String, dynamic>?)?['title'] as String?;
    final type = json['codec_type'] as String? ?? '';

    switch (type) {
      case 'video':
        if ((json['disposition'] as Map<String, dynamic>?)?['attached_pic'] ==
            1) {
          return DataStream(
            index: index,
            codec: codec,
            language: language,
            title: title,
          );
        }
        return VideoStream(
          index: index,
          codec: codec,
          language: language,
          title: title,
          width: json['width'] as int?,
          height: json['height'] as int?,
          frameRate: _parseRate(json['avg_frame_rate'] as String?),
          pixelFormat: json['pix_fmt'] as String?,
          colorTransfer: json['color_transfer'] as String?,
        );
      case 'audio':
        return AudioStream(
          index: index,
          codec: codec,
          language: language,
          title: title,
          sampleRate: int.tryParse('${json['sample_rate'] ?? ''}'),
          channels: json['channels'] as int?,
          bitDepth: int.tryParse('${json['bits_per_raw_sample'] ?? ''}'),
        );
      case 'subtitle':
        return SubtitleStream(
          index: index,
          codec: codec,
          language: language,
          title: title,
        );
      default:
        return DataStream(
          index: index,
          codec: codec,
          language: language,
          title: title,
        );
    }
  }

  double? _parseRate(String? raw) {
    if (raw == null || raw.isEmpty || raw == '0/0') return null;
    final parts = raw.split('/');
    if (parts.length == 2) {
      final a = double.tryParse(parts[0]);
      final b = double.tryParse(parts[1]);
      if (a != null && b != null && b != 0) return a / b;
    }
    return double.tryParse(raw);
  }

  static String _ext(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    return path.substring(dot + 1);
  }
}

/// Locates and runs ffprobe next to ffmpeg. Never used from widgets.
class Ffprobe {
  Ffprobe({this.ffprobePath, this.runner});

  final String? ffprobePath;
  final Future<ProcessResult> Function(String executable, List<String> args)?
      runner;

  static String? siblingOfFfmpeg(String ffmpegPath) {
    if (ffmpegPath.isEmpty) return null;
    final dir = p.dirname(ffmpegPath);
    final name = Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';
    final candidate = p.join(dir, name);
    if (File(candidate).existsSync()) return candidate;
    if (!Platform.isWindows && File(p.join(dir, 'ffprobe')).existsSync()) {
      return p.join(dir, 'ffprobe');
    }
    return null;
  }

  Future<MediaInfo> probe(String inputPath) async {
    final inferred = MediaInfo(
      path: inputPath,
      inferredType: inferMediaType(p.extension(inputPath).replaceFirst('.', '')),
    );
    final exe = ffprobePath;
    if (exe == null || exe.isEmpty) return inferred;

    try {
      final run = runner ?? Process.run;
      final result = await run(exe, [
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        inputPath,
      ]);
      if (result.exitCode != 0) return inferred;
      return const FfprobeParser().parseJson(
        result.stdout as String,
        path: inputPath,
      );
    } catch (_) {
      return inferred;
    }
  }
}
