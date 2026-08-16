import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/format_definitions.dart';

/// A destination recipe: container + default codecs + conversion options.
class FormatPreset {
  final String id;
  final String name;
  final MediaType category;
  final String container;
  final String extension;
  final String? videoCodec;
  final String? audioCodec;
  final ConversionOptions options;
  final bool isBuiltIn;

  const FormatPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.container,
    required this.extension,
    this.videoCodec,
    this.audioCodec,
    this.options = const ConversionOptions(),
    this.isBuiltIn = true,
  });

  String get displayExtension => extension.toUpperCase();

  ConversionOptions resolvedOptions() {
    return options.copyWith(
      videoEncoder: options.videoEncoder ?? videoCodec,
      audioEncoder: options.audioEncoder ?? audioCodec,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'container': container,
        'extension': extension,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'options': options.toJson(),
        'builtin': isBuiltIn,
      };

  factory FormatPreset.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String? ?? 'video';
    return FormatPreset(
      id: json['id'] as String? ?? json['extension'] as String? ?? 'custom',
      name: json['name'] as String? ??
          (json['extension'] as String? ?? 'custom').toUpperCase(),
      category: MediaType.values.firstWhere(
        (t) => t.name == categoryName,
        orElse: () => MediaType.unknown,
      ),
      container: json['container'] as String? ?? json['extension'] as String? ?? '',
      extension: (json['extension'] as String? ?? '').toLowerCase(),
      videoCodec: json['videoCodec'] as String?,
      audioCodec: json['audioCodec'] as String?,
      options: json['options'] is Map<String, dynamic>
          ? ConversionOptions.fromJson(json['options'] as Map<String, dynamic>)
          : const ConversionOptions(),
      isBuiltIn: json['builtin'] as bool? ?? false,
    );
  }

  static FormatPreset? byId(String id) {
    for (final p in builtins) {
      if (p.id == id) return p;
    }
    return null;
  }

  static FormatPreset? byExtension(String ext) {
    final normalized = ext.toLowerCase().replaceFirst('.', '');
    for (final p in builtins) {
      if (p.extension == normalized) return p;
    }
    return null;
  }

  static FormatPreset fromDefinition(FormatDefinition def) {
    return FormatPreset(
      id: '${def.type.name}_${def.extension}',
      name: def.extension.toUpperCase(),
      category: def.type,
      container: def.extension,
      extension: def.extension,
      videoCodec: def.defaultVideoEncoder,
      audioCodec: def.defaultAudioEncoder,
    );
  }

  /// First-ship built-ins. Do not enumerate every FFmpeg muxer here.
  static const List<FormatPreset> builtins = [
    FormatPreset(
      id: 'video_mp4',
      name: 'MP4',
      category: MediaType.video,
      container: 'mp4',
      extension: 'mp4',
      videoCodec: 'libx264',
      audioCodec: 'aac',
    ),
    FormatPreset(
      id: 'video_mkv',
      name: 'MKV',
      category: MediaType.video,
      container: 'mkv',
      extension: 'mkv',
      videoCodec: 'libx265',
      audioCodec: 'aac',
    ),
    FormatPreset(
      id: 'video_webm',
      name: 'WebM',
      category: MediaType.video,
      container: 'webm',
      extension: 'webm',
      videoCodec: 'libvpx-vp9',
      audioCodec: 'libopus',
    ),
    FormatPreset(
      id: 'video_mov',
      name: 'MOV',
      category: MediaType.video,
      container: 'mov',
      extension: 'mov',
      videoCodec: 'libx264',
      audioCodec: 'aac',
    ),
    FormatPreset(
      id: 'video_avi',
      name: 'AVI',
      category: MediaType.video,
      container: 'avi',
      extension: 'avi',
      videoCodec: 'mpeg4',
      audioCodec: 'libmp3lame',
    ),
    FormatPreset(
      id: 'video_gif',
      name: 'GIF',
      category: MediaType.video,
      container: 'gif',
      extension: 'gif',
    ),
    FormatPreset(
      id: 'audio_mp3',
      name: 'MP3',
      category: MediaType.audio,
      container: 'mp3',
      extension: 'mp3',
      audioCodec: 'libmp3lame',
      options: ConversionOptions(bitrateKbps: 192),
    ),
    FormatPreset(
      id: 'audio_aac',
      name: 'AAC',
      category: MediaType.audio,
      container: 'aac',
      extension: 'aac',
      audioCodec: 'aac',
    ),
    FormatPreset(
      id: 'audio_flac',
      name: 'FLAC',
      category: MediaType.audio,
      container: 'flac',
      extension: 'flac',
      audioCodec: 'flac',
    ),
    FormatPreset(
      id: 'audio_wav',
      name: 'WAV',
      category: MediaType.audio,
      container: 'wav',
      extension: 'wav',
      audioCodec: 'pcm_s16le',
    ),
    FormatPreset(
      id: 'audio_ogg',
      name: 'OGG',
      category: MediaType.audio,
      container: 'ogg',
      extension: 'ogg',
      audioCodec: 'libvorbis',
    ),
    FormatPreset(
      id: 'audio_opus',
      name: 'Opus',
      category: MediaType.audio,
      container: 'opus',
      extension: 'opus',
      audioCodec: 'libopus',
    ),
    FormatPreset(
      id: 'audio_m4a',
      name: 'M4A',
      category: MediaType.audio,
      container: 'm4a',
      extension: 'm4a',
      audioCodec: 'aac',
    ),
    FormatPreset(
      id: 'image_png',
      name: 'PNG',
      category: MediaType.image,
      container: 'png',
      extension: 'png',
      audioCodec: 'png',
    ),
    FormatPreset(
      id: 'image_jpeg',
      name: 'JPEG',
      category: MediaType.image,
      container: 'jpg',
      extension: 'jpg',
      audioCodec: 'mjpeg',
    ),
    FormatPreset(
      id: 'image_webp',
      name: 'WebP',
      category: MediaType.image,
      container: 'webp',
      extension: 'webp',
      audioCodec: 'libwebp',
    ),
    FormatPreset(
      id: 'image_avif',
      name: 'AVIF',
      category: MediaType.image,
      container: 'avif',
      extension: 'avif',
      audioCodec: 'libaom-av1',
    ),
  ];
}

/// Quality shortcuts applied on top of a [FormatPreset].
class QualityProfile {
  final String id;
  final int? crf;
  final int? audioBitrateKbps;
  final int? imageQuality;

  const QualityProfile({
    required this.id,
    this.crf,
    this.audioBitrateKbps,
    this.imageQuality,
  });

  static const high = QualityProfile(
    id: 'high',
    crf: 18,
    audioBitrateKbps: 320,
    imageQuality: 95,
  );

  static const standard = QualityProfile(
    id: 'standard',
    crf: 23,
    audioBitrateKbps: 192,
    imageQuality: 85,
  );

  static const small = QualityProfile(
    id: 'small',
    crf: 28,
    audioBitrateKbps: 128,
    imageQuality: 70,
  );

  static const all = [high, standard, small];
}
