import 'package:teigi/core/models/conversion_options.dart';

/// 预设模板：快速选择「高质量」「体积优先」等，可自定义保存。
class FormatPreset {
  final String name;
  final String? targetFormat;
  final ConversionOptions options;

  const FormatPreset({
    required this.name,
    this.targetFormat,
    required this.options,
  });

  /// 内置预设。
  static const List<FormatPreset> builtin = [
    FormatPreset(
      name: '高质量',
      options: ConversionOptions(
        crf: 18,
        bitrateKbps: 320,
        imageQuality: 95,
      ),
    ),
    FormatPreset(
      name: '体积优先',
      options: ConversionOptions(
        crf: 30,
        bitrateKbps: 96,
        imageQuality: 70,
      ),
    ),
    FormatPreset(
      name: '移动端',
      options: ConversionOptions(
        crf: 26,
        resolution: '1280x720',
        frameRate: 30,
        bitrateKbps: 160,
        sampleRate: 44100,
        channels: 2,
      ),
    ),
  ];
}
