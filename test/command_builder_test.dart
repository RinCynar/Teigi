import 'package:flutter_test/flutter_test.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_command_builder.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/media_file.dart';

void main() {
  ConversionTask task({
    String path = '/media/a.mkv',
    String? target = 'mp4',
    ConversionOptions options = const ConversionOptions(),
  }) {
    return ConversionTask(
      id: 't1',
      source: MediaFile(path: path),
      targetFormat: target,
      options: options,
    );
  }

  group('FfmpegCommandBuilder', () {
    const builder = FfmpegCommandBuilder();

    test('throws when target format is missing', () {
      expect(
        () => builder.build(task(target: null)),
        throwsArgumentError,
      );
    });

    test('default MP4 uses libx264 + aac and preserves metadata', () {
      final command = builder.build(
        task(options: const ConversionOptions(outputDirectory: '/out')),
      );
      expect(command.args, containsAllInOrder(['-i', '/media/a.mkv']));
      expect(command.args, containsAllInOrder(['-c:v', 'libx264']));
      expect(command.args, containsAllInOrder(['-c:a', 'aac']));
      expect(command.args, containsAllInOrder(['-map_metadata', '0']));
      expect(command.args.last, contains('a.mp4'));
      expect(command.preview, startsWith('ffmpeg '));
    });

    test('copy streams and hardware encoder mapping', () {
      final args = builder.buildArgs(
        task(
          options: const ConversionOptions(
            copyVideo: true,
            copyAudio: true,
            hardwareAccel: true,
            outputDirectory: '/out',
          ),
        ),
        '/out/a.mp4',
      );
      expect(args, containsAllInOrder(['-c:v', 'copy']));
      expect(args, containsAllInOrder(['-c:a', 'copy']));
      expect(args, isNot(contains('h264_nvenc')));
    });

    test('maps libx264 to nvenc when hardware accel is on', () {
      final args = builder.buildArgs(
        task(
          options: const ConversionOptions(
            hardwareAccel: true,
            outputDirectory: '/out',
          ),
        ),
        '/out/a.mp4',
      );
      expect(args, containsAllInOrder(['-c:v', 'h264_nvenc']));
    });

    test('applies audio bitrate and quality', () {
      final args = builder.buildArgs(
        task(
          target: 'mp4',
          options: const ConversionOptions(
            crf: 20,
            bitrateKbps: 320,
            outputDirectory: '/out',
          ),
        ),
        '/out/a.mp4',
      );
      expect(args, containsAllInOrder(['-b:a', '320k']));
      expect(args, containsAllInOrder(['-crf', '20']));
    });

    test('Android maps MP4 and MKV to mediacodec and uses -b:v', () {
      const androidBuilder = FfmpegCommandBuilder(isAndroidOverride: true);
      final mp4Cmd = androidBuilder.build(
        task(
          target: 'mp4',
          options: const ConversionOptions(crf: 23, outputDirectory: '/out'),
        ),
      );
      expect(mp4Cmd.args, containsAllInOrder(['-c:v', 'h264_mediacodec']));
      expect(mp4Cmd.args, containsAllInOrder(['-b:v', '3500k']));
      expect(mp4Cmd.args, containsAllInOrder(['-pix_fmt', 'yuv420p']));
      expect(mp4Cmd.args, isNot(contains('-crf')));

      final mkvCmd = androidBuilder.build(
        task(
          target: 'mkv',
          options: const ConversionOptions(crf: 18, outputDirectory: '/out'),
        ),
      );
      expect(mkvCmd.args, containsAllInOrder(['-c:v', 'hevc_mediacodec']));
      expect(mkvCmd.args, containsAllInOrder(['-b:v', '6000k']));
      expect(mkvCmd.args, isNot(contains('-crf')));
    });

    test('Opus audio conversion configures -vn, -c:a libopus, -ar 48000, -b:a', () {
      const androidBuilder = FfmpegCommandBuilder(isAndroidOverride: true);
      final opusCmd = androidBuilder.build(
        task(
          target: 'opus',
          options: const ConversionOptions(outputDirectory: '/out'),
        ),
      );
      expect(opusCmd.args, contains('-vn'));
      expect(opusCmd.args, containsAllInOrder(['-c:a', 'libopus']));
      expect(opusCmd.args, containsAllInOrder(['-ar', '48000']));
      expect(opusCmd.args, containsAllInOrder(['-b:a', '128k']));
    });
  });
}
