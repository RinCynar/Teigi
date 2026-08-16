import 'package:teigi/core/domain/media_type.dart';

export 'package:teigi/core/domain/media_type.dart';

/// 内置格式定义：扩展名、所属类别、以及智能默认的编码参数。
class FormatDefinition {
  final String extension; // 如 'mp4'、'flac'
  final MediaType type;

  /// 默认视频编码器（视频格式专用）。
  final String? defaultVideoEncoder;

  /// 默认音频编码器。
  final String? defaultAudioEncoder;

  /// 支持的容器描述（仅作展示）。
  final String description;

  const FormatDefinition({
    required this.extension,
    required this.type,
    this.defaultVideoEncoder,
    this.defaultAudioEncoder,
    required this.description,
  });
}

/// 内置常见格式列表。
const List<FormatDefinition> builtinFormats = [
  // ---- 视频 ----
  FormatDefinition(
    extension: 'mp4',
    type: MediaType.video,
    defaultVideoEncoder: 'libx264',
    defaultAudioEncoder: 'aac',
    description: 'H.264 + AAC，通用性最佳',
  ),
  FormatDefinition(
    extension: 'mkv',
    type: MediaType.video,
    defaultVideoEncoder: 'libx265',
    defaultAudioEncoder: 'aac',
    description: 'Matroska 封装，支持多种编码',
  ),
  FormatDefinition(
    extension: 'webm',
    type: MediaType.video,
    defaultVideoEncoder: 'libvpx-vp9',
    defaultAudioEncoder: 'libopus',
    description: 'Web 专用，VP9 + Opus',
  ),
  FormatDefinition(
    extension: 'avi',
    type: MediaType.video,
    defaultVideoEncoder: 'mpeg4',
    defaultAudioEncoder: 'libmp3lame',
    description: '旧式兼容容器',
  ),
  FormatDefinition(
    extension: 'mov',
    type: MediaType.video,
    defaultVideoEncoder: 'libx264',
    defaultAudioEncoder: 'aac',
    description: 'QuickTime 容器',
  ),
  FormatDefinition(
    extension: 'hevc',
    type: MediaType.video,
    defaultVideoEncoder: 'libx265',
    description: 'HEVC/H.265 裸流',
  ),
  FormatDefinition(
    extension: 'gif',
    type: MediaType.video,
    description: 'GIF 动图',
  ),
  // ---- 音频 ----
  FormatDefinition(
    extension: 'mp3',
    type: MediaType.audio,
    defaultAudioEncoder: 'libmp3lame',
    description: 'MPEG-1 Layer 3',
  ),
  FormatDefinition(
    extension: 'aac',
    type: MediaType.audio,
    defaultAudioEncoder: 'aac',
    description: 'AAC 音频',
  ),
  FormatDefinition(
    extension: 'flac',
    type: MediaType.audio,
    defaultAudioEncoder: 'flac',
    description: '无损压缩',
  ),
  FormatDefinition(
    extension: 'wav',
    type: MediaType.audio,
    defaultAudioEncoder: 'pcm_s16le',
    description: '无压缩 PCM',
  ),
  FormatDefinition(
    extension: 'opus',
    type: MediaType.audio,
    defaultAudioEncoder: 'libopus',
    description: 'Opus 高效压缩',
  ),
  FormatDefinition(
    extension: 'ogg',
    type: MediaType.audio,
    defaultAudioEncoder: 'libvorbis',
    description: 'Ogg Vorbis',
  ),
  FormatDefinition(
    extension: 'm4a',
    type: MediaType.audio,
    defaultAudioEncoder: 'aac',
    description: 'AAC 音频（MP4 容器）',
  ),
  FormatDefinition(
    extension: 'wma',
    type: MediaType.audio,
    defaultAudioEncoder: 'wmav2',
    description: 'Windows Media Audio',
  ),
  // ---- 图片 ----
  FormatDefinition(
    extension: 'jpg',
    type: MediaType.image,
    defaultAudioEncoder: 'mjpeg',
    description: 'JPEG 有损压缩',
  ),
  FormatDefinition(
    extension: 'png',
    type: MediaType.image,
    defaultAudioEncoder: 'png',
    description: 'PNG 无损',
  ),
  FormatDefinition(
    extension: 'webp',
    type: MediaType.image,
    defaultAudioEncoder: 'libwebp',
    description: 'WebP 现代压缩',
  ),
  FormatDefinition(
    extension: 'avif',
    type: MediaType.image,
    defaultAudioEncoder: 'libaom-av1',
    description: 'AV1 图像格式',
  ),
  FormatDefinition(
    extension: 'bmp',
    type: MediaType.image,
    defaultAudioEncoder: 'bmp',
    description: 'BMP 位图',
  ),
  FormatDefinition(
    extension: 'tiff',
    type: MediaType.image,
    defaultAudioEncoder: 'tiff',
    description: 'TIFF 位图',
  ),
];

/// 查找内置格式定义；找不到返回 null。
FormatDefinition? findBuiltinFormat(String extension) {
  final ext = extension.toLowerCase();
  for (final f in builtinFormats) {
    if (f.extension == ext) return f;
  }
  return null;
}
