import 'package:flutter/foundation.dart';

/// 是否有真实桌面窗口（Windows / Linux / macOS）。
bool get isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// 是否为移动平台（Android / iOS）。
bool get isMobile =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// 是否为 Android 平台。
bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// 是否为 iOS 平台。
bool get isIOS =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
