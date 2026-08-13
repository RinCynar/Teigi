/// 硬件加速能力检测结果。
class HardwareAccelCapabilities {
  /// 支持的硬件编码器列表。
  final List<String> encoders;

  const HardwareAccelCapabilities({this.encoders = const []});

  bool get isNvencAvailable =>
      encoders.any((e) => e.contains('nvenc'));

  bool get isQsvAvailable =>
      encoders.any((e) => e.contains('qsv'));

  bool get isAmfAvailable =>
      encoders.any((e) => e.contains('amf'));

  bool get isVideoToolboxAvailable =>
      encoders.any((e) => e.contains('videotoolbox'));

  bool get isEmpty => encoders.isEmpty;

  /// 汇总描述，如「NVENC · QSV」。
  String get summary {
    final names = <String>[];
    if (isNvencAvailable) names.add('NVENC');
    if (isQsvAvailable) names.add('QSV');
    if (isAmfAvailable) names.add('AMF');
    if (isVideoToolboxAvailable) names.add('VideoToolbox');
    return names.join(' · ');
  }
}

/// 解析 ffmpeg `-encoders` 输出，提取硬件编码器。
class HardwareAccelDetector {
  /// 从 `ffmpeg -encoders` 的输出文本中解析可用编码器。
  static HardwareAccelCapabilities parseEncoders(String output) {
    final encoders = <String>[];
    for (final line in output.split('\n')) {
      // 示例： V....D libx264              libx264 H.264 ...
      // 硬件编码器行形如：V..... h264_nvenc ...
      final trimmed = line.trimLeft();
      if (!trimmed.startsWith('V')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 3) continue;
      final name = parts[1].toLowerCase();
      // 收集已知硬件编码器。
      if (name.contains('nvenc') ||
          name.contains('qsv') ||
          name.contains('amf') ||
          name.contains('videotoolbox')) {
        encoders.add(name);
      }
    }
    return HardwareAccelCapabilities(encoders: encoders);
  }
}
