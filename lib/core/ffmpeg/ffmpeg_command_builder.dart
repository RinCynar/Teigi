import 'package:teigi/core/ffmpeg/ffmpeg_command.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_definitions.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/core/utils/file_naming.dart';
import 'package:teigi/core/utils/platform_info.dart';

/// Builds an [FfmpegCommand] from a [ConversionTask].
///
/// All encoder / filter / mapping decisions belong here — not in widgets.
class FfmpegCommandBuilder {
  final bool? isAndroidOverride;

  const FfmpegCommandBuilder({this.isAndroidOverride});

  bool get _isAndroid => isAndroidOverride ?? isAndroid;

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
    final target = task.targetFormat ?? '';
    final args = <String>['-y', '-hide_banner'];

    args.addAll(['-i', task.source.path]);

    if (options.threads > 0) {
      args.addAll(['-threads', '${options.threads}']);
    }

    args.addAll(['-map_metadata', '0']);

    final isAudioOnly = findBuiltinFormat(target)?.type == MediaType.audio ||
        FormatPreset.byExtension(target)?.category == MediaType.audio ||
        kDefaultAudioEncoders.containsKey(target);
    final isImageOnly = findBuiltinFormat(target)?.type == MediaType.image ||
        FormatPreset.byExtension(target)?.category == MediaType.image;

    if (isAudioOnly) {
      args.add('-vn');
    } else if (isImageOnly) {
      args.add('-an');
    }

    if (!isAudioOnly) {
      if (!options.copyVideo) {
        var encoder = options.videoEncoder ?? defaultVideoEncoder(task);
        if (_isAndroid) {
          encoder = _adaptAndroidVideoEncoder(encoder, target);
        } else if (options.hardwareAccel && encoder.isNotEmpty) {
          encoder = hardwareEncoder(encoder);
        }
        if (encoder.isNotEmpty) {
          args.addAll(['-c:v', encoder]);
        }
        if (encoder.contains('mediacodec')) {
          // MediaCodec 硬件编码器不支持 -crf 选项，转为使用 -b:v 控制码率
          final bitrate = _crfToBitrate(options.crf);
          args.addAll(['-b:v', bitrate]);
          if (options.pixelFormat != null) {
            args.addAll(['-pix_fmt', options.pixelFormat!]);
          } else {
            args.addAll(['-pix_fmt', 'yuv420p']);
          }
        } else {
          if (options.crf != null) {
            args.addAll(['-crf', '${options.crf}']);
          }
          if (options.pixelFormat != null) {
            args.addAll(['-pix_fmt', options.pixelFormat!]);
          }
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
      } else {
        args.addAll(['-c:v', 'copy']);
      }
    }

    if (!options.copyAudio) {
      var encoder = options.audioEncoder ?? defaultAudioEncoder(task);
      if (_isAndroid) {
        encoder = _adaptAndroidAudioEncoder(encoder, target);
      }
      if (encoder.isNotEmpty) {
        args.addAll(['-c:a', encoder]);
      }
      if (encoder == 'opus') {
        args.addAll(['-strict', '-2']);
      }
      if (options.bitrateKbps != null) {
        args.addAll(['-b:a', '${options.bitrateKbps}k']);
      } else if (target == 'opus' || encoder.contains('opus')) {
        args.addAll(['-b:a', '128k']);
      }
      if (options.sampleRate != null) {
        args.addAll(['-ar', '${options.sampleRate}']);
      } else if (target == 'opus' || encoder.contains('opus')) {
        // Opus 音频标准采样率强制适配 48000 Hz，避免 44.1kHz 源文件触发 FFmpeg 报错
        args.addAll(['-ar', '48000']);
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

  String _crfToBitrate(int? crf) {
    if (crf == null) return '3500k';
    if (crf <= 18) return '6000k';
    if (crf <= 23) return '3500k';
    if (crf <= 28) return '2000k';
    return '1200k';
  }

  String _adaptAndroidVideoEncoder(String encoder, String targetFormat) {
    switch (encoder) {
      case 'libx264':
      case 'h264':
      case 'h264_nvenc':
      case 'h264_qsv':
      case 'h264_amf':
        return 'h264_mediacodec';
      case 'libx265':
      case 'hevc':
      case 'hevc_nvenc':
      case 'hevc_qsv':
      case 'hevc_amf':
        return 'hevc_mediacodec';
      case 'libvpx-vp9':
      case 'vp9':
      case 'vp9_qsv':
        return 'vp9_mediacodec';
      case 'libvpx':
      case 'vp8':
        return 'vp8_mediacodec';
      case 'mpeg4_qsv':
        return 'mpeg4';
      default:
        if (encoder.isEmpty) {
          if (targetFormat == 'mp4' || targetFormat == 'mov' || targetFormat == 'm4v') {
            return 'h264_mediacodec';
          }
          if (targetFormat == 'mkv' || targetFormat == 'hevc') {
            return 'hevc_mediacodec';
          }
        }
        return encoder;
    }
  }

  String _adaptAndroidAudioEncoder(String encoder, String targetFormat) {
    switch (encoder) {
      case 'libopus':
      case 'opus':
        return 'libopus';
      case 'libvorbis':
        return 'vorbis';
      case 'libopencore_amrnb':
        return 'amr_nb';
      default:
        if (encoder.isEmpty && targetFormat == 'opus') {
          return 'libopus';
        }
        return encoder;
    }
  }

  String defaultVideoEncoder(ConversionTask task) {
    final target = task.targetFormat ?? '';
    if (_isAndroid && kAndroidDefaultVideoEncoders.containsKey(target)) {
      return kAndroidDefaultVideoEncoders[target]!;
    }
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

const Map<String, String> kAndroidDefaultVideoEncoders = {
  'mp4': 'h264_mediacodec',
  'mkv': 'hevc_mediacodec',
  'webm': 'vp9_mediacodec',
  'avi': 'mpeg4',
  'mov': 'h264_mediacodec',
  'hevc': 'hevc_mediacodec',
  'gif': '',
  'flv': 'flv1',
  'm4v': 'h264_mediacodec',
};

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
