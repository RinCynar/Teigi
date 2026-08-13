import 'package:path/path.dart' as p;

/// 表示一个待转换的媒体文件。
class MediaFile {
  final String path;

  const MediaFile({required this.path});

  /// 文件名（含扩展名）。
  String get name => p.basename(path);

  /// 无扩展名的主文件名。
  String get baseName => p.basenameWithoutExtension(path);

  /// 扩展名（小写，不含点），如 'mp4'、'jpg'。
  String get extension => p.extension(path).replaceFirst('.', '').toLowerCase();

  /// 所在目录。
  String get directory => p.dirname(path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaFile && other.path == path);

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'MediaFile($path)';
}
