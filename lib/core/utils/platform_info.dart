import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// 是否有真实桌面窗口（Windows / Linux / macOS）。
bool get isDesktop =>
    !kIsWeb &&
    (Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS);

/// 是否为移动平台（Android / iOS）。
bool get isMobile =>
    !kIsWeb &&
    (Platform.isAndroid || Platform.isIOS);

/// 是否为 Android 平台。
bool get isAndroid =>
    !kIsWeb && Platform.isAndroid;

/// 是否为 iOS 平台。
bool get isIOS =>
    !kIsWeb && Platform.isIOS;
