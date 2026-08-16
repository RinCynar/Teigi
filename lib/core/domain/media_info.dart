import 'package:teigi/core/domain/media_type.dart';

/// One stream inside a media container.
sealed class MediaStream {
  final int index;
  final String? codec;
  final String? language;
  final String? title;

  const MediaStream({
    required this.index,
    this.codec,
    this.language,
    this.title,
  });
}

class VideoStream extends MediaStream {
  final int? width;
  final int? height;
  final double? frameRate;
  final String? pixelFormat;
  final String? colorTransfer;

  const VideoStream({
    required super.index,
    super.codec,
    super.language,
    super.title,
    this.width,
    this.height,
    this.frameRate,
    this.pixelFormat,
    this.colorTransfer,
  });

  String? get resolutionLabel {
    if (width == null || height == null) return null;
    return '$width × $height';
  }
}

class AudioStream extends MediaStream {
  final int? sampleRate;
  final int? channels;
  final int? bitDepth;

  const AudioStream({
    required super.index,
    super.codec,
    super.language,
    super.title,
    this.sampleRate,
    this.channels,
    this.bitDepth,
  });
}

class SubtitleStream extends MediaStream {
  const SubtitleStream({
    required super.index,
    super.codec,
    super.language,
    super.title,
  });
}

class DataStream extends MediaStream {
  const DataStream({
    required super.index,
    super.codec,
    super.language,
    super.title,
  });
}

/// Probe result for one input file.
class MediaInfo {
  final String path;
  final String? format;
  final Duration? duration;
  final int? sizeBytes;
  final int? bitrate;
  final List<MediaStream> streams;
  final MediaType inferredType;
  final bool probed;

  const MediaInfo({
    required this.path,
    this.format,
    this.duration,
    this.sizeBytes,
    this.bitrate,
    this.streams = const [],
    this.inferredType = MediaType.unknown,
    this.probed = false,
  });

  List<VideoStream> get videoStreams =>
      streams.whereType<VideoStream>().toList();

  List<AudioStream> get audioStreams =>
      streams.whereType<AudioStream>().toList();

  List<SubtitleStream> get subtitleStreams =>
      streams.whereType<SubtitleStream>().toList();

  VideoStream? get primaryVideo =>
      videoStreams.isEmpty ? null : videoStreams.first;

  AudioStream? get primaryAudio =>
      audioStreams.isEmpty ? null : audioStreams.first;

  MediaType get type {
    if (inferredType != MediaType.unknown) return inferredType;
    if (videoStreams.isNotEmpty) return MediaType.video;
    if (audioStreams.isNotEmpty) return MediaType.audio;
    if (subtitleStreams.isNotEmpty) return MediaType.subtitle;
    return MediaType.unknown;
  }
}
