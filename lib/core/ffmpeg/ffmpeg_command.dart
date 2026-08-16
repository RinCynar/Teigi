/// Immutable argv for one FFmpeg invocation. UI must never assemble this.
class FfmpegCommand {
  final List<String> args;
  final String outputPath;

  const FfmpegCommand({required this.args, required this.outputPath});

  /// Human-readable preview for Advanced settings. Not an executable string.
  String get preview {
    final escaped = args.map(_quoteIfNeeded).join(' ');
    return 'ffmpeg $escaped';
  }

  static String _quoteIfNeeded(String value) {
    if (value.contains(' ') || value.contains("'")) {
      return '"$value"';
    }
    return value;
  }
}
