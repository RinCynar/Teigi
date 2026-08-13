import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/media_file.dart';

/// 输出文件命名工具。
class FileNaming {
  /// 默认模板：`{name}.{ext}`。
  static const String defaultTemplate = '{name}.{ext}';

  /// 根据源文件、目标扩展名与模板生成输出路径。
  ///
  /// [OverwritePolicy.keepBoth] 时若目标已存在，自动追加
  /// ` (1)`、` (2)` 等后缀。
  static String buildOutputPath({
    required MediaFile source,
    required String targetExtension,
    String? outputDirectory,
    String? template,
    OverwritePolicy overwritePolicy = OverwritePolicy.keepBoth,
  }) {
    final dir = (outputDirectory == null || outputDirectory.isEmpty)
        ? source.directory
        : outputDirectory;

    final base = template == null || template.isEmpty
        ? defaultTemplate
        : template;

    var fileName = _applyTemplate(base, source, targetExtension);
    var fullPath = p.join(dir, fileName);

    if (overwritePolicy == OverwritePolicy.keepBoth) {
      fullPath = _avoidConflict(fullPath);
    }
    return fullPath;
  }

  /// 应用模板占位符。
  static String _applyTemplate(
    String template,
    MediaFile source,
    String targetExtension,
  ) {
    return template
        .replaceAll('{name}', source.baseName)
        .replaceAll('{ext}', targetExtension)
        .replaceAll('{ext_upper}', targetExtension.toUpperCase());
  }

  /// 若路径已存在，追加 ` (n)` 后缀。
  static String _avoidConflict(String path) {
    if (!File(path).existsSync()) return path;
    final dir = p.dirname(path);
    final ext = p.extension(path);
    final stem = p.basenameWithoutExtension(path);

    var i = 1;
    while (true) {
      final candidate = p.join(dir, '$stem ($i)$ext');
      if (!File(candidate).existsSync()) return candidate;
      i++;
    }
  }
}
