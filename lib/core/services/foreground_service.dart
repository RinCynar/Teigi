import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:teigi/core/utils/platform_info.dart';

/// Android 前台服务管理：转码期间保持进程存活，常驻通知展示进度与取消按钮。
///
/// 仅在 Android 上有效；桌面/iOS 上调用都是安全的 no-op。
///
/// 前后台切换后转码是否持续、Android 14 及以下 mediaProcessing 类型兼容性。
class ForegroundService {
  static bool _initialized = false;
  static StreamController<ForegroundAction>? _actionController;

  static const int _serviceId = 257;
  static const String _cancelActionId = 'cancel';
  static DateTime? _lastProgressUpdate;

  /// 通知按钮（取消）回传的事件流。
  static Stream<ForegroundAction> get actions =>
      _actionController?.stream ?? const Stream<ForegroundAction>.empty();

  static void initialize() {
    if (_initialized) return;
    _actionController = StreamController<ForegroundAction>.broadcast();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'teigi_conversion',
        channelName: 'Teigi 转换',
        channelDescription: '媒体转换进行中',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _initialized = true;
  }

  /// Android 13+ 请求通知权限（前台服务通知需要）。非 Android 下为 no-op。
  static Future<void> ensureNotificationPermission() async {
    if (!isAndroid) return;
    initialize();
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// 转码开始时启动前台服务。
  static Future<void> start({required String fileName}) async {
    if (!isAndroid) return;
    initialize();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationText: fileName);
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: 'Teigi 转换中',
      notificationText: fileName,
      notificationIcon: null,
      notificationButtons: const [
        NotificationButton(id: _cancelActionId, text: '取消'),
      ],
      serviceTypes: const [ForegroundServiceTypes.mediaProcessing],
      callback: startCallback,
    );
  }

  /// 更新通知内容（如进度百分比）。内部做 500ms 节流，避免高频刷新。
  static Future<void> updateProgress(String text) async {
    if (!isAndroid || !_initialized) return;
    final now = DateTime.now();
    if (_lastProgressUpdate != null &&
        now.difference(_lastProgressUpdate!).inMilliseconds < 500) {
      return;
    }
    _lastProgressUpdate = now;
    if (!await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.updateService(notificationText: text);
  }

  /// 转码结束或队列清空时停止前台服务。
  static Future<void> stop() async {
    if (!isAndroid || !_initialized) return;
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _actionController?.close();
    _actionController = null;
    _initialized = false;
  }

  static void _onTaskData(Object data) {
    if (data is Map && data['action'] == _cancelActionId) {
      _actionController?.add(ForegroundAction.cancel);
    }
  }
}

/// 前台服务通知回调触发的动作。
enum ForegroundAction { cancel }

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_ConversionTaskHandler());
}

class _ConversionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == ForegroundService._cancelActionId) {
      FlutterForegroundTask.sendDataToMain({'action': ForegroundService._cancelActionId});
    }
  }

  @override
  void onNotificationPressed() {}

  @override
  void onNotificationDismissed() {}
}
