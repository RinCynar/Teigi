import 'package:teigi/core/domain/media_info.dart';
import 'package:teigi/core/domain/media_type.dart';
import 'package:teigi/core/domain/media_type_infer.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/core/models/media_file.dart';

/// Suggested output for an input file. Never applied silently in the UI.
class RecommendedPreset {
  final FormatPreset preset;
  final String reason;

  const RecommendedPreset({required this.preset, required this.reason});
}

/// Maps input media to a built-in destination preset.
class PresetRecommendationService {
  const PresetRecommendationService();

  RecommendedPreset? recommendForFile(MediaFile file) {
    return recommend(
      type: file.mediaType,
      extension: file.extension,
    );
  }

  RecommendedPreset? recommendForInfo(MediaInfo info) {
    return recommend(
      type: info.type,
      extension: _extOf(info.path),
      info: info,
    );
  }

  RecommendedPreset? recommend({
    required MediaType type,
    required String extension,
    MediaInfo? info,
  }) {
    final ext = extension.toLowerCase().replaceFirst('.', '');
    final video = info?.primaryVideo;

    if (type == MediaType.audio ||
        (type == MediaType.unknown && inferMediaType(ext) == MediaType.audio)) {
      if (ext == 'flac' || ext == 'wav' || ext == 'aiff' || ext == 'ape') {
        return RecommendedPreset(
          preset: FormatPreset.byId('audio_mp3')!,
          reason: 'Archive audio → MP3',
        );
      }
      return RecommendedPreset(
        preset: FormatPreset.byId('audio_mp3')!,
        reason: 'Audio → MP3',
      );
    }

    if (type == MediaType.image) {
      if (ext == 'png' || ext == 'bmp' || ext == 'tiff' || ext == 'tif') {
        return RecommendedPreset(
          preset: FormatPreset.byId('image_webp')!,
          reason: 'Lossless still → WebP',
        );
      }
      return RecommendedPreset(
        preset: FormatPreset.byId('image_jpeg')!,
        reason: 'Image → JPEG',
      );
    }

    if (type == MediaType.video || type == MediaType.unknown) {
      final isHdr = video?.colorTransfer != null &&
          video!.colorTransfer!.toLowerCase().contains('smpte2084');
      if (isHdr || (video?.width ?? 0) >= 3840) {
        return RecommendedPreset(
          preset: FormatPreset.byId('video_mp4')!,
          reason: 'High-res video → MP4',
        );
      }
      if (ext == 'avi') {
        return RecommendedPreset(
          preset: FormatPreset.byId('video_mp4')!,
          reason: 'Legacy AVI → MP4',
        );
      }
      return RecommendedPreset(
        preset: FormatPreset.byId('video_mp4')!,
        reason: 'Video → MP4',
      );
    }

    return null;
  }

  String? recommendExtension(MediaFile file) {
    return recommendForFile(file)?.preset.extension;
  }

  static String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0) return '';
    return path.substring(dot + 1).toLowerCase();
  }
}
