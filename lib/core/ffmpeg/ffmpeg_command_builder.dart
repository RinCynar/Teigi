import 'package:teigi/core/ffmpeg/ffmpeg_command.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_definitions.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/core/utils/file_naming.dart';

/// Builds an [FfmpegCommand] from a [ConversionTask].
///
/// All encoder / filter / mapping decisions belong here — not in widgets.
class FfmpegCommandBuilder {
  const FfmpegCommandBuilder();

  FfmpegCommand build(ConversionTask task, {String? outputPath}) {
    final target = task.targetFormat;
    if (target == null || target.isEmpty) {
      throw ArgumentError('任务未指定目标格式：${task.source.path}');
    }

    final resolvedOutput = outputPath ??
        FileNaming.buildOutputPath(
          source: task.source,
          targetExtension: target,
          outputDirectory: task.options.outputDirectory,
          template: task.options.fileNameTemplate,
          overwritePolicy: task.options.overwritePolicy,
        );

    return FfmpegCommand(
      args: buildArgs(task, resolvedOutput),
      outputPath: resolvedOutput,
    );
  }

  /// Construct argv. Always uses `-y`; conflict policy is applied by [FileNaming].
  List<String> buildArgs(ConversionTask task, String outputPath) {
    final options = task.options;
    final args = <String>['-y', '-hide_banner'];

    args.addAll(['-i', task.source.path]);

    if (options.threads > 0) {
      args.addAll(['-threads', '${options.threads}']);
    }

    args.addAll(['-map_metadata', '0']);

    if (!options.copyVideo) {
      var encoder = options.videoEncoder ?? defaultVideoEncoder(task);
      if (options.hardwareAccel && encoder.isNotEmpty) {
        encoder = hardwareEncoder(encoder);
      }
      if (encoder.isNotEmpty) {
        args.addAll(['-c:v', encoder]);
      }
      if (options.crf != null) {
        args.addAll(['-crf', '${options.crf}']);
      }
      if (options.resolution != null) {
        args.addAll(['-vf', 'scale=${options.resolution}']);
      }
      if (options.maxResolution != null) {
        final parts = options.maxResolution!.split('x');
        if (parts.length == 2) {
          final w = int.tryParse(parts[0]);
          final h = int.tryParse(parts[1]);
          if (w != null && h != null && w > 0 && h > 0) {
            final filter =
                'scale=min(iw\\,$w)\\,min(ih\\,$h):force_original_aspect_ratio=decrease';
            args.addAll(['-vf', filter]);
          }
        }
      }
      if (options.frameRate != null) {
        args.addAll(['-r', '${options.frameRate}']);
      }
      if (options.pixelFormat != null) {
        args.addAll(['-pix_fmt', options.pixelFormat!]);
      }
    } else {
      args.addAll(['-c:v', 'copy']);
    }

    if (!options.copyAudio) {
      final encoder = options.audioEncoder ?? defaultAudioEncoder(task);
      if (encoder.isNotEmpty) {
        args.addAll(['-c:a', encoder]);
      }
      if (options.bitrateKbps != null) {
        args.addAll(['-b:a', '${options.bitrateKbps}k']);
      }
      if (options.sampleRate != null) {
        args.addAll(['-ar', '${options.sampleRate}']);
      }
      if (options.channels != null) {
        args.addAll(['-ac', '${options.channels}']);
      }
      if (options.volume != null) {
        args.addAll(['-af', 'volume=${options.volume! / 100}']);
      }
    } else {
      args.addAll(['-c:a', 'copy']);
    }

    args.add(outputPath);
    return args;
  }

  String defaultVideoEncoder(ConversionTask task) {
    final target = task.targetFormat ?? '';
    if (kDefaultVideoEncoders.containsKey(target)) {
      return kDefaultVideoEncoders[target]!;
    }
    return FormatPreset.byExtension(target)?.videoCodec ??
        findBuiltinFormat(target)?.defaultVideoEncoder ??
        '';
  }

  String defaultAudioEncoder(ConversionTask task) {
    final target = task.targetFormat ?? '';
    if (kDefaultAudioEncoders.containsKey(target)) {
      return kDefaultAudioEncoders[target]!;
    }
    return FormatPreset.byExtension(target)?.audioCodec ??
        findBuiltinFormat(target)?.defaultAudioEncoder ??
        '';
  }

  String hardwareEncoder(String encoder) {
    return kHardwareEncoders[encoder] ?? encoder;
  }
}

const Map<String, String> kDefaultVideoEncoders = {
  'mp4': 'libx264',
  'mkv': 'libx265',
  'webm': 'libvpx-vp9',
  'avi': 'mpeg4',
  'mov': 'libx264',
  'hevc': 'libx265',
  'gif': '',
  'flv': 'flv1',
  'm4v': 'libx264',
};

const Map<String, String> kHardwareEncoders = {
  'libx264': 'h264_nvenc',
  'libx265': 'hevc_nvenc',
  'libvpx-vp9': 'vp9_qsv',
  'mpeg4': 'mpeg4_qsv',
};

const Map<String, String> kDefaultAudioEncoders = {
  'mp3': 'libmp3lame',
  'aac': 'aac',
  'flac': 'flac',
  'wav': 'pcm_s16le',
  'opus': 'libopus',
  'ogg': 'libvorbis',
  'm4a': 'aac',
  'wma': 'wmav2',
  'ac3': 'ac3',
  'amr': 'libopencore_amrnb',
};
