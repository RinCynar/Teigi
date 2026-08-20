# ProGuard / R8 rules for Teigi Android release builds

# FFmpegKit JNI & Reflection rules
-keep class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**

# Flutter Foreground Task
-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn com.pravera.flutter_foreground_task.**

# Receive Sharing Intent
-keep class com.kasem.receive_sharing_intent.** { *; }
-dontwarn com.kasem.receive_sharing_intent.**
