import 'package:flutter_test/flutter_test.dart';
import 'package:teigi/core/domain/conversion_error.dart';
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/domain/media_type_infer.dart';
import 'package:teigi/core/domain/preset_recommendation.dart';
import 'package:teigi/core/ffmpeg/ffprobe.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/core/models/media_file.dart';
import 'package:teigi/core/services/task_scheduler.dart';
import 'package:teigi/core/utils/file_naming.dart';

void main() {
  group('inferMediaType', () {
    test('uses builtin and fallback maps', () {
      expect(inferMediaType('mkv'), MediaType.video);
      expect(inferMediaType('flac'), MediaType.audio);
      expect(inferMediaType('png'), MediaType.image);
      expect(inferMediaType('srt'), MediaType.subtitle);
      expect(inferMediaType('pdf'), MediaType.document);
      expect(inferMediaType('xyz'), MediaType.unknown);
      expect(inferMediaType('.MP3'), MediaType.audio);
    });
  });

  group('PresetRecommendationService', () {
    const service = PresetRecommendationService();

    test('recommends MP4 for video and MP3 for archive audio', () {
      final video = service.recommendForFile(const MediaFile(path: 'a.mkv'));
      expect(video?.preset.extension, 'mp4');

      final flac = service.recommendForFile(const MediaFile(path: 'a.flac'));
      expect(flac?.preset.id, 'audio_mp3');

      final png = service.recommendForFile(const MediaFile(path: 'a.png'));
      expect(png?.preset.extension, 'webp');
    });
  });

  group('FormatPreset', () {
    test('round-trips json and lookup', () {
      final preset = FormatPreset.byId('video_mp4');
      expect(preset, isNotNull);
      final json = preset!.toJson();
      final restored = FormatPreset.fromJson(json);
      expect(restored.extension, 'mp4');
      expect(restored.videoCodec, 'libx264');
      expect(FormatPreset.byExtension('webm')?.id, 'video_webm');
    });
  });

  group('TaskScheduler', () {
    test('respects concurrency and skips non-queued', () {
      const scheduler = TaskScheduler();
      final tasks = [
        ConversionTask(
          id: '1',
          source: const MediaFile(path: 'a.mp4'),
          targetFormat: 'mp4',
        ),
        ConversionTask(
          id: '2',
          source: const MediaFile(path: 'b.mp4'),
          targetFormat: 'mp4',
        ),
        ConversionTask(
          id: '3',
          source: const MediaFile(path: 'c.mp4'),
          targetFormat: 'mp4',
          status: TaskStatus.running,
        ),
      ];
      final picked = scheduler.selectNext(
        tasks: tasks,
        runningCount: 1,
        concurrency: 2,
      );
      expect(picked, hasLength(1));
      expect(picked.first.id, '1');
      expect(scheduler.isExhausted(tasks), isFalse);
    });
  });

  group('FfprobeParser', () {
    test('parses streams and duration', () {
      const raw = '''
{
  "format": {
    "format_name": "matroska,webm",
    "duration": "12.5",
    "size": "2048",
    "bit_rate": "1000"
  },
  "streams": [
    {
      "index": 0,
      "codec_type": "video",
      "codec_name": "hevc",
      "width": 1920,
      "height": 1080,
      "avg_frame_rate": "30/1"
    },
    {
      "index": 1,
      "codec_type": "audio",
      "codec_name": "flac",
      "sample_rate": "48000",
      "channels": 2,
      "tags": { "language": "jpn" }
    }
  ]
}
''';
      final info = const FfprobeParser().parseJson(raw, path: 'clip.mkv');
      expect(info.probed, isTrue);
      expect(info.duration, const Duration(milliseconds: 12500));
      expect(info.videoStreams.single.width, 1920);
      expect(info.audioStreams.single.language, 'jpn');
      expect(info.type, MediaType.video);
    });
  });

  group('FileNaming', () {
    test('applies template placeholders', () {
      final path = FileNaming.buildOutputPath(
        source: const MediaFile(path: 'C:/media/Movie.mkv'),
        targetExtension: 'mp4',
        outputDirectory: 'D:/out',
        template: '{name}_{ext}',
        overwritePolicy: OverwritePolicy.overwrite,
      );
      expect(path.replaceAll('\\\\', '/'), contains('Movie_mp4'));
    });
  });

  group('ConversionError.fromFfmpeg', () {
    test('maps cancelled results to cancelled', () {
      final error = ConversionError.fromFfmpeg(
        exitCode: 1,
        cancelled: true,
        error: 'ffmpeg 已取消',
        stderr: 'raw log',
      );
      expect(error.kind, ConversionErrorKind.cancelled);
      expect(error.details, 'raw log');
    });

    test('maps common stderr to friendly kinds', () {
      expect(
        ConversionError.fromFfmpeg(
          exitCode: 1,
          cancelled: false,
          stderr: 'No such file or directory',
        ).kind,
        ConversionErrorKind.invalidInput,
      );
      expect(
        ConversionError.fromFfmpeg(
          exitCode: 1,
          cancelled: false,
          stderr: 'Permission denied',
        ).kind,
        ConversionErrorKind.permissionDenied,
      );
      expect(
        ConversionError.fromFfmpeg(
          exitCode: 1,
          cancelled: false,
          stderr: 'Unknown encoder: nope',
        ).kind,
        ConversionErrorKind.unsupportedCodec,
      );
    });
  });
}
