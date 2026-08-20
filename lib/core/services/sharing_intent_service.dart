import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:teigi/core/models/media_file.dart';
import 'package:teigi/core/utils/platform_info.dart';

/// 移动端系统分享 Intent 接收服务（Android / iOS）。
///
/// 当用户在相册、文件管理器或第三方应用中点击「分享到 Teigi」时，
/// 本服务负责解析传入的文件路径并回调业务层注入转换队列。
/// 桌面平台下所有方法均为 no-op。
class SharingIntentService {
  SharingIntentService._();
  static final SharingIntentService instance = SharingIntentService._();

  StreamSubscription<List<SharedMediaFile>>? _subscription;

  /// 初始化分享接收监听。仅在移动平台生效。
  void init({required void Function(List<MediaFile> files) onFilesReceived}) {
    if (!isMobile) return;

    // 1. 应用在后台运行时接收到的分享（热启动/前台切回）
    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> shared) {
        _handleSharedMedia(shared, onFilesReceived);
      },
      onError: (err) {
        debugPrint('ReceiveSharingIntent getMediaStream error: $err');
      },
    );

    // 2. 应用冷启动时从外部分享打开
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> shared) {
          _handleSharedMedia(shared, onFilesReceived);
          ReceiveSharingIntent.instance.reset();
        })
        .catchError((err) {
          debugPrint('ReceiveSharingIntent getInitialMedia error: $err');
        });
  }

  void _handleSharedMedia(
    List<SharedMediaFile> shared,
    void Function(List<MediaFile> files) onFilesReceived,
  ) {
    if (shared.isEmpty) return;
    final files = <MediaFile>[];
    for (final item in shared) {
      if (item.path.isNotEmpty) {
        files.add(MediaFile(path: item.path));
      }
    }
    if (files.isNotEmpty) {
      onFilesReceived(files);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
