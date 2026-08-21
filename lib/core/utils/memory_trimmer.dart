import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/painting.dart';

typedef _GetCurrentProcessC = IntPtr Function();
typedef _GetCurrentProcessDart = int Function();

typedef _EmptyWorkingSetC = Int32 Function(IntPtr hProcess);
typedef _EmptyWorkingSetDart = int Function(int hProcess);

/// Windows 桌面端物理工作集裁剪与空闲内存整理管理器。
class MemoryTrimmer {
  static bool _initialized = false;
  static _GetCurrentProcessDart? _getCurrentProcess;
  static _EmptyWorkingSetDart? _emptyWorkingSet;

  static void _init() {
    if (_initialized) return;
    _initialized = true;
    if (!Platform.isWindows) return;
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      _getCurrentProcess = kernel32
          .lookupFunction<_GetCurrentProcessC, _GetCurrentProcessDart>(
            'GetCurrentProcess',
          );

      final psapi = DynamicLibrary.open('psapi.dll');
      _emptyWorkingSet = psapi
          .lookupFunction<_EmptyWorkingSetC, _EmptyWorkingSetDart>(
            'EmptyWorkingSet',
          );
    } catch (_) {}
  }

  /// 裁剪当前进程的物理内存工作集，通知 Windows 回收未使用的物理页。
  static void trimWorkingSet() {
    if (!Platform.isWindows) return;
    _init();
    try {
      final hProcess = _getCurrentProcess?.call();
      if (hProcess != null && _emptyWorkingSet != null) {
        _emptyWorkingSet!(hProcess);
      }
    } catch (_) {}
  }

  /// 触发空闲期内存整理：清理图片缓存并异步调度物理工作集裁剪。
  static void trimIdleMemory({
    Duration delay = const Duration(milliseconds: 300),
  }) {
    if (!Platform.isWindows) return;
    Timer(delay, () {
      try {
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
      trimWorkingSet();
    });
  }
}
