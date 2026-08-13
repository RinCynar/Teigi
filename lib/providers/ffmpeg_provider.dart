import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/ffmpeg/ffmpeg_detector.dart';
import 'package:teigi/providers/settings_provider.dart';

/// ffmpeg 检测状态。
enum FfmpegDetectionStatus { unknown, checking, available, unavailable }

/// ffmpeg 可用性状态。
class FfmpegStatus {
  final FfmpegDetectionStatus status;
  final FfmpegInfo info;
  final String? message;

  const FfmpegStatus({
    this.status = FfmpegDetectionStatus.unknown,
    this.info = FfmpegInfo.unavailable,
    this.message,
  });

  FfmpegStatus copyWith({
    FfmpegDetectionStatus? status,
    FfmpegInfo? info,
    String? message,
  }) {
    return FfmpegStatus(
      status: status ?? this.status,
      info: info ?? this.info,
      message: message ?? this.message,
    );
  }

  bool get isAvailable => status == FfmpegDetectionStatus.available;
}

/// ffmpeg 检测状态 Provider。
final ffmpegStatusProvider =
    AsyncNotifierProvider<FfmpegStatusNotifier, FfmpegStatus>(() {
  return FfmpegStatusNotifier();
});

class FfmpegStatusNotifier extends AsyncNotifier<FfmpegStatus> {
  static final FfmpegDetector _detector = FfmpegDetector();

  @override
  Future<FfmpegStatus> build() {
    return _detect();
  }

  /// 重新检测（如用户更新了自定义路径后）。
  Future<FfmpegStatus> redetect() async {
    state = const AsyncLoading();
    final result = await _detect();
    state = AsyncData(result);
    return result;
  }

  Future<FfmpegStatus> _detect() async {
    final settings = ref.read(settingsProvider);
    final info = await _detector.detect(customPath: settings.ffmpegPath);
    if (info.isAvailable) {
      return FfmpegStatus(
        status: FfmpegDetectionStatus.available,
        info: info,
        message: '已找到 ffmpeg ${info.version}',
      );
    }
    return const FfmpegStatus(
      status: FfmpegDetectionStatus.unavailable,
      message: '未找到 ffmpeg，请在设置中指定可执行文件路径',
    );
  }
}
