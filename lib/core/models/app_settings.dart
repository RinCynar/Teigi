import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/core/models/conversion_options.dart';

/// 应用设置项（持久化到 shared_preferences）。
class AppSettings {
  /// 用户自定义 ffmpeg 路径（空 = 未指定）。
  final String ffmpegPath;

  /// 默认输出目录（空 = 与源文件同目录）。
  final String outputDirectory;

  /// 并发转换数。
  final int concurrency;

  /// 是否默认启用硬件加速。
  final bool hardwareAccel;

  /// 主题模式：system / light / dark。
  final String themeMode;

  /// 完成后是否自动打开输出目录。
  final bool openOutputAfterDone;

  /// 文件冲突策略。
  final OverwritePolicy overwritePolicy;

  /// 日志级别：debug / info / warn / error。
  final String logLevel;

  /// 语言代码：system / zh / ja / en。
  final String language;

  const AppSettings({
    this.ffmpegPath = '',
    this.outputDirectory = '',
    this.concurrency = 2,
    this.hardwareAccel = false,
    this.themeMode = 'system',
    this.openOutputAfterDone = false,
    this.overwritePolicy = OverwritePolicy.keepBoth,
    this.logLevel = 'info',
    this.language = 'system',
  });

  AppSettings copyWith({
    String? ffmpegPath,
    String? outputDirectory,
    int? concurrency,
    bool? hardwareAccel,
    String? themeMode,
    bool? openOutputAfterDone,
    OverwritePolicy? overwritePolicy,
    String? logLevel,
    String? language,
  }) {
    return AppSettings(
      ffmpegPath: ffmpegPath ?? this.ffmpegPath,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      concurrency: concurrency ?? this.concurrency,
      hardwareAccel: hardwareAccel ?? this.hardwareAccel,
      themeMode: themeMode ?? this.themeMode,
      openOutputAfterDone: openOutputAfterDone ?? this.openOutputAfterDone,
      overwritePolicy: overwritePolicy ?? this.overwritePolicy,
      logLevel: logLevel ?? this.logLevel,
      language: language ?? this.language,
    );
  }

  /// 从 SharedPreferences 读取。
  static Future<AppSettings> load(SharedPreferences prefs) async {
    return AppSettings(
      ffmpegPath: prefs.getString('ffmpeg_path') ?? '',
      outputDirectory: prefs.getString('output_directory') ?? '',
      concurrency: prefs.getInt('concurrency') ?? 2,
      hardwareAccel: prefs.getBool('hardware_accel') ?? false,
      themeMode: prefs.getString('theme_mode') ?? 'system',
      openOutputAfterDone: prefs.getBool('open_output_after_done') ?? false,
      overwritePolicy: OverwritePolicy.values[
          prefs.getInt('overwrite_policy') ?? OverwritePolicy.keepBoth.index],
      logLevel: prefs.getString('log_level') ?? 'info',
      language: prefs.getString('language') ?? 'system',
    );
  }

  /// 保存到 SharedPreferences。
  Future<void> save(SharedPreferences prefs) async {
    await prefs.setString('ffmpeg_path', ffmpegPath);
    await prefs.setString('output_directory', outputDirectory);
    await prefs.setInt('concurrency', concurrency);
    await prefs.setBool('hardware_accel', hardwareAccel);
    await prefs.setString('theme_mode', themeMode);
    await prefs.setBool('open_output_after_done', openOutputAfterDone);
    await prefs.setInt('overwrite_policy', overwritePolicy.index);
    await prefs.setString('log_level', logLevel);
    await prefs.setString('language', language);
  }
}
