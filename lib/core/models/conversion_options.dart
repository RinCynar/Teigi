/// 文件名冲突时的覆盖策略。
enum OverwritePolicy { keepBoth, overwrite, skip }

/// 单个转换任务的完整参数。
/// 字段均为可选：为 null 时表示使用 ffmpeg 默认值或「智能默认」。
class ConversionOptions {
  // ---- 视频 ----
  final String? videoEncoder; // 如 libx264 / libx265 / h264_nvenc
  final int? crf; // 0-51，越小质量越高
  final String? resolution; // 如 '1920x1080'、'1280x720'
  final double? frameRate; // fps
  final String? pixelFormat; // 如 yuv420p
  final bool copyVideo;

  // ---- 音频 ----
  final String? audioEncoder; // 如 aac / libmp3lame / flac
  final int? bitrateKbps; // 音频码率 kbps
  final int? sampleRate; // Hz
  final int? channels; // 声道数
  final int? volume; // 音量百分比 0-200
  final bool copyAudio;

  // ---- 图片 ----
  final int? imageQuality; // 0-100
  final String? imageScale; // 如 '50%'
  final String? maxResolution; // 图片最大分辨率，如 '1920x1080'

  // ---- 通用 ----
  final bool hardwareAccel; // 是否启用 GPU 加速
  final int threads; // ffmpeg 线程数（0 = 自动）
  final String? outputDirectory; // 输出目录（null = 使用默认）
  final String? fileNameTemplate; // 如 '{name}_converted.{ext}'
  final OverwritePolicy overwritePolicy;

  const ConversionOptions({
    this.videoEncoder,
    this.crf,
    this.resolution,
    this.frameRate,
    this.pixelFormat,
    this.copyVideo = false,
    this.audioEncoder,
    this.bitrateKbps,
    this.sampleRate,
    this.channels,
    this.volume,
    this.copyAudio = false,
    this.imageQuality,
    this.imageScale,
    this.maxResolution,
    this.hardwareAccel = false,
    this.threads = 0,
    this.outputDirectory,
    this.fileNameTemplate,
    this.overwritePolicy = OverwritePolicy.keepBoth,
  });

  ConversionOptions copyWith({
    String? videoEncoder,
    int? crf,
    String? resolution,
    double? frameRate,
    String? pixelFormat,
    bool? copyVideo,
    String? audioEncoder,
    int? bitrateKbps,
    int? sampleRate,
    int? channels,
    int? volume,
    bool? copyAudio,
    int? imageQuality,
    String? imageScale,
    String? maxResolution,
    bool? hardwareAccel,
    int? threads,
    String? outputDirectory,
    String? fileNameTemplate,
    OverwritePolicy? overwritePolicy,
  }) {
    return ConversionOptions(
      videoEncoder: videoEncoder ?? this.videoEncoder,
      crf: crf ?? this.crf,
      resolution: resolution ?? this.resolution,
      frameRate: frameRate ?? this.frameRate,
      pixelFormat: pixelFormat ?? this.pixelFormat,
      copyVideo: copyVideo ?? this.copyVideo,
      audioEncoder: audioEncoder ?? this.audioEncoder,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      volume: volume ?? this.volume,
      copyAudio: copyAudio ?? this.copyAudio,
      imageQuality: imageQuality ?? this.imageQuality,
      imageScale: imageScale ?? this.imageScale,
      maxResolution: maxResolution ?? this.maxResolution,
      hardwareAccel: hardwareAccel ?? this.hardwareAccel,
      threads: threads ?? this.threads,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      fileNameTemplate: fileNameTemplate ?? this.fileNameTemplate,
      overwritePolicy: overwritePolicy ?? this.overwritePolicy,
    );
  }

  /// 序列化为 JSON（供快捷格式持久化）。
  Map<String, dynamic> toJson() => {
        'videoEncoder': videoEncoder,
        'crf': crf,
        'resolution': resolution,
        'frameRate': frameRate,
        'pixelFormat': pixelFormat,
        'copyVideo': copyVideo,
        'audioEncoder': audioEncoder,
        'bitrateKbps': bitrateKbps,
        'sampleRate': sampleRate,
        'channels': channels,
        'volume': volume,
        'copyAudio': copyAudio,
        'imageQuality': imageQuality,
        'imageScale': imageScale,
        'maxResolution': maxResolution,
        'hardwareAccel': hardwareAccel,
        'threads': threads,
        'outputDirectory': outputDirectory,
        'fileNameTemplate': fileNameTemplate,
        'overwritePolicy': overwritePolicy.index,
      };

  /// 从 JSON 反序列化。
  factory ConversionOptions.fromJson(Map<String, dynamic> json) {
    return ConversionOptions(
      videoEncoder: json['videoEncoder'] as String?,
      crf: json['crf'] as int?,
      resolution: json['resolution'] as String?,
      frameRate: (json['frameRate'] as num?)?.toDouble(),
      pixelFormat: json['pixelFormat'] as String?,
      copyVideo: json['copyVideo'] as bool? ?? false,
      audioEncoder: json['audioEncoder'] as String?,
      bitrateKbps: json['bitrateKbps'] as int?,
      sampleRate: json['sampleRate'] as int?,
      channels: json['channels'] as int?,
      volume: json['volume'] as int?,
      copyAudio: json['copyAudio'] as bool? ?? false,
      imageQuality: json['imageQuality'] as int?,
      imageScale: json['imageScale'] as String?,
      maxResolution: json['maxResolution'] as String?,
      hardwareAccel: json['hardwareAccel'] as bool? ?? false,
      threads: json['threads'] as int? ?? 0,
      outputDirectory: json['outputDirectory'] as String?,
      fileNameTemplate: json['fileNameTemplate'] as String?,
      overwritePolicy: OverwritePolicy.values[
          (json['overwritePolicy'] as int?) ?? OverwritePolicy.keepBoth.index],
    );
  }
}
