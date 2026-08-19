import 'package:teigi/core/ffmpeg/engine/desktop_ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/engine/mobile_ffmpeg_engine.dart';
import 'package:teigi/core/utils/platform_info.dart';

/// Selects the [FfmpegEngine] implementation for the current platform.
class FfmpegEngineFactory {
  const FfmpegEngineFactory._();

  static FfmpegEngine create() {
    if (isMobile) return MobileFfmpegEngine();
    return DesktopFfmpegEngine();
  }
}
