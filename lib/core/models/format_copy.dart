import 'package:teigi/core/models/format_preset.dart';

/// Short product copy for a destination. Not FFmpeg internals.
class FormatCopy {
  final String title;
  final String summary;
  final String detail;
  final bool custom;

  const FormatCopy({
    required this.title,
    required this.summary,
    required this.detail,
    this.custom = false,
  });

  static FormatCopy of(String extension) {
    final ext = extension.toLowerCase().replaceFirst('.', '');
    final preset = FormatPreset.byExtension(ext);
    return switch (ext) {
      'mp4' => const FormatCopy(
          title: 'MP4',
          summary: 'H.264 / AAC',
          detail: 'MPEG-4 container',
        ),
      'mkv' => const FormatCopy(
          title: 'MKV',
          summary: 'H.265 / AAC',
          detail: 'Matroska container',
        ),
      'webm' => const FormatCopy(
          title: 'WebM',
          summary: 'VP9 / Opus',
          detail: 'Web container',
        ),
      'mov' => const FormatCopy(
          title: 'MOV',
          summary: 'H.264 / AAC',
          detail: 'QuickTime container',
        ),
      'avi' => const FormatCopy(
          title: 'AVI',
          summary: 'MPEG-4',
          detail: 'Legacy container',
        ),
      'gif' => const FormatCopy(
          title: 'GIF',
          summary: 'Animated image',
          detail: 'Graphics interchange',
        ),
      'mp3' => const FormatCopy(
          title: 'MP3',
          summary: 'MPEG audio',
          detail: 'Widely compatible',
        ),
      'aac' => const FormatCopy(
          title: 'AAC',
          summary: 'AAC audio',
          detail: 'Compressed audio',
        ),
      'flac' => const FormatCopy(
          title: 'FLAC',
          summary: 'Lossless audio',
          detail: 'Archive quality',
        ),
      'wav' => const FormatCopy(
          title: 'WAV',
          summary: 'PCM audio',
          detail: 'Uncompressed',
        ),
      'ogg' => const FormatCopy(
          title: 'OGG',
          summary: 'Vorbis',
          detail: 'Ogg container',
        ),
      'opus' => const FormatCopy(
          title: 'Opus',
          summary: 'Opus audio',
          detail: 'Low-latency audio',
        ),
      'm4a' => const FormatCopy(
          title: 'M4A',
          summary: 'AAC',
          detail: 'MPEG-4 audio',
        ),
      'png' => const FormatCopy(
          title: 'PNG',
          summary: 'Lossless image',
          detail: 'Still image',
        ),
      'jpg' || 'jpeg' => const FormatCopy(
          title: 'JPEG',
          summary: 'Photo image',
          detail: 'Still image',
        ),
      'webp' => const FormatCopy(
          title: 'WebP',
          summary: 'Modern image',
          detail: 'Still image',
        ),
      'avif' => const FormatCopy(
          title: 'AVIF',
          summary: 'AV1 image',
          detail: 'Still image',
        ),
      _ => FormatCopy(
          title: ext.toUpperCase(),
          summary: preset?.audioCodec ?? preset?.videoCodec ?? 'Custom extension',
          detail: 'Custom extension',
          custom: preset == null,
        ),
    };
  }

  static List<FormatCopy> search(String query) {
    return [
      for (final p in FormatPreset.builtins) FormatCopy.of(p.extension),
    ].where((c) => c.matches(query)).toList();
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        summary.toLowerCase().contains(q) ||
        detail.toLowerCase().contains(q);
  }
}
