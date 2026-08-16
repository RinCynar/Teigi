import 'dart:io';

/// Local file facts for UI identity. Does not call FFmpeg.
class FileIdentity {
  static String? sizeLabel(String path) {
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(0)} KB';
      }
      if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } catch (_) {
      return null;
    }
  }

  static bool isReadableImage(String extension) {
    const ok = {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'};
    return ok.contains(extension.toLowerCase());
  }
}
