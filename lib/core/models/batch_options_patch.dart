import 'package:teigi/core/models/conversion_options.dart';

/// One field in a batch edit: leave it, set a value, or reset to Auto/Original.
sealed class FieldPatch<T> {
  const FieldPatch();
}

class Unchanged<T> extends FieldPatch<T> {
  const Unchanged();
}

class SetValue<T> extends FieldPatch<T> {
  final T value;
  const SetValue(this.value);
}

class SetAuto<T> extends FieldPatch<T> {
  const SetAuto();
}

/// Partial update applied to many tasks. Unchanged fields are left alone.
class BatchOptionsPatch {
  final FieldPatch<String?> videoEncoder;
  final FieldPatch<int?> crf;
  final FieldPatch<String?> resolution;
  final FieldPatch<double?> frameRate;
  final FieldPatch<String?> pixelFormat;
  final FieldPatch<bool> copyVideo;
  final FieldPatch<String?> audioEncoder;
  final FieldPatch<int?> bitrateKbps;
  final FieldPatch<int?> sampleRate;
  final FieldPatch<int?> channels;
  final FieldPatch<int?> volume;
  final FieldPatch<bool> copyAudio;
  final FieldPatch<int?> imageQuality;
  final FieldPatch<String?> imageScale;
  final FieldPatch<String?> maxResolution;

  const BatchOptionsPatch({
    this.videoEncoder = const Unchanged(),
    this.crf = const Unchanged(),
    this.resolution = const Unchanged(),
    this.frameRate = const Unchanged(),
    this.pixelFormat = const Unchanged(),
    this.copyVideo = const Unchanged(),
    this.audioEncoder = const Unchanged(),
    this.bitrateKbps = const Unchanged(),
    this.sampleRate = const Unchanged(),
    this.channels = const Unchanged(),
    this.volume = const Unchanged(),
    this.copyAudio = const Unchanged(),
    this.imageQuality = const Unchanged(),
    this.imageScale = const Unchanged(),
    this.maxResolution = const Unchanged(),
  });

  ConversionOptions apply(ConversionOptions base) {
    return ConversionOptions(
      videoEncoder: _str(videoEncoder, base.videoEncoder),
      crf: _int(crf, base.crf),
      resolution: _str(resolution, base.resolution),
      frameRate: switch (frameRate) {
        Unchanged<double?>() => base.frameRate,
        SetValue<double?>(:final value) => value,
        SetAuto<double?>() => null,
      },
      pixelFormat: _str(pixelFormat, base.pixelFormat),
      copyVideo: switch (copyVideo) {
        Unchanged<bool>() => base.copyVideo,
        SetValue<bool>(:final value) => value,
        SetAuto<bool>() => false,
      },
      audioEncoder: _str(audioEncoder, base.audioEncoder),
      bitrateKbps: _int(bitrateKbps, base.bitrateKbps),
      sampleRate: _int(sampleRate, base.sampleRate),
      channels: _int(channels, base.channels),
      volume: _int(volume, base.volume),
      copyAudio: switch (copyAudio) {
        Unchanged<bool>() => base.copyAudio,
        SetValue<bool>(:final value) => value,
        SetAuto<bool>() => false,
      },
      imageQuality: _int(imageQuality, base.imageQuality),
      imageScale: _str(imageScale, base.imageScale),
      maxResolution: _str(maxResolution, base.maxResolution),
      hardwareAccel: base.hardwareAccel,
      threads: base.threads,
      outputDirectory: base.outputDirectory,
      fileNameTemplate: base.fileNameTemplate,
      overwritePolicy: base.overwritePolicy,
    );
  }

  static String? _str(FieldPatch<String?> patch, String? current) {
    return switch (patch) {
      Unchanged<String?>() => current,
      SetValue<String?>(:final value) => value,
      SetAuto<String?>() => null,
    };
  }

  static int? _int(FieldPatch<int?> patch, int? current) {
    return switch (patch) {
      Unchanged<int?>() => current,
      SetValue<int?>(:final value) => value,
      SetAuto<int?>() => null,
    };
  }
}
