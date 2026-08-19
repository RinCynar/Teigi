import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine.dart';
import 'package:teigi/core/ffmpeg/engine/ffmpeg_engine_factory.dart';
import 'package:teigi/providers/settings_provider.dart';

/// The currently selected FFmpeg engine implementation.
final ffmpegEngineProvider = Provider<FfmpegEngine>((ref) {
  return FfmpegEngineFactory.create();
});

/// Current FFmpeg engine detection state.
final ffmpegStatusProvider =
    AsyncNotifierProvider<FfmpegStatusNotifier, FfmpegEngineStatus>(() {
  return FfmpegStatusNotifier();
});

class FfmpegStatusNotifier extends AsyncNotifier<FfmpegEngineStatus> {
  @override
  Future<FfmpegEngineStatus> build() {
    return _detect();
  }

  /// Re-detect after the user changes the executable path.
  Future<FfmpegEngineStatus> redetect() async {
    state = const AsyncLoading();
    final result = await _detect();
    state = AsyncData(result);
    return result;
  }

  Future<FfmpegEngineStatus> _detect() {
    final settings = ref.read(settingsProvider);
    return ref.read(ffmpegEngineProvider).detect(
          customExecutablePath: settings.ffmpegPath,
        );
  }
}
