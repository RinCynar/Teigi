import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/ffmpeg/engine/desktop_ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_command_builder.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_detector.dart';
import 'package:teigi/core/ffmpeg/ffprobe.dart';
import 'package:teigi/core/ffmpeg/progress_parser.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/media_file.dart';

void main() {
  late String ffmpegPath;
  late String ffprobePath;
  Directory? tempDir;
  late File videoSource;
  late File audioSource;

  setUpAll(() async {
    ffmpegPath = await _findExecutable('ffmpeg');
    if (ffmpegPath.isEmpty) return;
    ffprobePath = p.join(
      p.dirname(ffmpegPath),
      Platform.isWindows ? 'ffprobe.exe' : 'ffprobe',
    );
    if (!File(ffprobePath).existsSync()) {
      ffmpegPath = '';
      return;
    }

    tempDir = await Directory.systemTemp.createTemp('teigi_ffmpeg_acceptance_');
    videoSource = File(p.join(tempDir!.path, 'source.mp4'));
    audioSource = File(p.join(tempDir!.path, 'source.wav'));

    final encoders = await Process.run(ffmpegPath, ['-encoders']);
    final encoderText = (encoders.stdout as String).toLowerCase();
    if (!encoderText.contains('mpeg4') || !encoderText.contains('aac')) {
      ffmpegPath = '';
      return;
    }

    final video = await Process.run(ffmpegPath, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=128x128:rate=10',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=44100',
      '-t',
      '1',
      '-c:v',
      'mpeg4',
      '-c:a',
      'aac',
      videoSource.path,
    ]);
    final audio = await Process.run(ffmpegPath, [
      '-hide_banner',
      '-loglevel',
      'error',
      '-y',
      '-f',
      'lavfi',
      '-i',
      'sine=frequency=440:sample_rate=44100',
      '-t',
      '1',
      '-c:a',
      'pcm_s16le',
      audioSource.path,
    ]);
    if (video.exitCode != 0 || audio.exitCode != 0) {
      ffmpegPath = '';
    }
  });

  tearDownAll(() async {
    if (tempDir != null && tempDir!.existsSync()) {
      await tempDir!.delete(recursive: true);
    }
  });

  test(
    'custom / bundled / systemPath 视频与音频转换验收',
    () async {
      if (ffmpegPath.isEmpty) return;

      await _runVideoAndAudio(
        tempDir: tempDir!,
        ffprobePath: ffprobePath,
        videoSource: videoSource,
        audioSource: audioSource,
        label: 'custom',
        expectedSource: FfmpegEngineSource.custom,
        detector: FfmpegDetector(),
        customExecutablePath: ffmpegPath,
      );
      await _runVideoAndAudio(
        tempDir: tempDir!,
        ffprobePath: ffprobePath,
        videoSource: videoSource,
        audioSource: audioSource,
        label: 'bundled',
        expectedSource: FfmpegEngineSource.bundled,
        detector: FfmpegDetector(
          bundledPathResolver: () async => ffmpegPath,
          pathResolver: () async => null,
        ),
      );
      await _runVideoAndAudio(
        tempDir: tempDir!,
        ffprobePath: ffprobePath,
        videoSource: videoSource,
        audioSource: audioSource,
        label: 'systemPath',
        expectedSource: FfmpegEngineSource.systemPath,
        detector: FfmpegDetector(bundledPathResolver: () async => null),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _runVideoAndAudio({
  required Directory tempDir,
  required String ffprobePath,
  required File videoSource,
  required File audioSource,
  required String label,
  required FfmpegEngineSource expectedSource,
  required FfmpegDetector detector,
  String? customExecutablePath,
}) async {
  final engine = DesktopFfmpegEngine(detector: detector);
  final status = await engine.detect(
    customExecutablePath: customExecutablePath,
  );
  expect(status.isReady, isTrue, reason: '$label should detect ffmpeg');
  expect(status.source, expectedSource);

  await _convert(
    tempDir: tempDir,
    ffprobePath: ffprobePath,
    engine: engine,
    label: '$label-video',
    input: videoSource,
    targetExtension: 'mkv',
    options: const ConversionOptions(
      videoEncoder: 'mpeg4',
      audioEncoder: 'aac',
      threads: 1,
    ),
    expectedType: MediaType.video,
  );
  await _convert(
    tempDir: tempDir,
    ffprobePath: ffprobePath,
    engine: engine,
    label: '$label-audio',
    input: audioSource,
    targetExtension: 'm4a',
    options: const ConversionOptions(audioEncoder: 'aac', threads: 1),
    expectedType: MediaType.audio,
  );
}

Future<void> _convert({
  required Directory tempDir,
  required String ffprobePath,
  required DesktopFfmpegEngine engine,
  required String label,
  required File input,
  required String targetExtension,
  required ConversionOptions options,
  required MediaType expectedType,
}) async {
  final task = ConversionTask(
    id: 'accept_$label',
    source: MediaFile(path: input.path),
    targetFormat: targetExtension,
    options: options.copyWith(
      outputDirectory: tempDir.path,
      overwritePolicy: OverwritePolicy.overwrite,
    ),
  );
  final command = const FfmpegCommandBuilder().build(task);
  final progress = <ProgressUpdate>[];
  final handle = engine.run(command);
  final progressSubscription = handle.progress.listen(progress.add);

  final result = await handle.result;
  await progressSubscription.cancel();

  expect(result.isSuccess, isTrue, reason: '$label: ${result.error}');
  final output = File(command.outputPath);
  expect(output.existsSync(), isTrue, reason: '$label should create output');
  expect(output.lengthSync(), greaterThan(0));

  final info = await Ffprobe(ffprobePath: ffprobePath).probe(output.path);
  expect(
    info.type,
    expectedType,
    reason: '$label should produce $expectedType',
  );
}

Future<String> _findExecutable(String name) async {
  final pathVar = Platform.environment['PATH'];
  if (pathVar == null || pathVar.isEmpty) return '';

  final separator = Platform.isWindows ? ';' : ':';
  final extensions = Platform.isWindows
      ? const ['.exe', '.cmd', '.bat', '.com']
      : const [''];

  for (final dir in pathVar.split(separator)) {
    final directory = dir.trim();
    if (directory.isEmpty) continue;
    for (final ext in extensions) {
      final candidate = p.join(directory, '$name$ext');
      if (File(candidate).existsSync()) return candidate;
    }
  }
  return '';
}
