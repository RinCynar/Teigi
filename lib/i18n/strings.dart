import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/providers/settings_provider.dart';

/// 轻量级本地化：支持 简体中文(zh) / 日本語(ja) / English(en)。
///
/// 所有界面文案集中在此，通过 [l10nProvider] 随语言设置切换。
class L10n {
  final String language;

  const L10n(this.language);

  static const supported = ['zh', 'ja', 'en'];

  String _t(Map<String, String> m) => m[language] ?? m['en'] ?? m.values.first;

  /// 格式化时长（剩余时间等）。
  String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // ---- 应用/导航 ----
  String get appTitle => _t({'zh': 'Teigi', 'ja': 'Teigi', 'en': 'Teigi'});
  String get navQueue => _t({'zh': '队列', 'ja': 'キュー', 'en': 'Queue'});
  String get navSettings => _t({'zh': '设置', 'ja': '設定', 'en': 'Settings'});
  String get menu => _t({'zh': '菜单', 'ja': 'メニュー', 'en': 'Menu'});

  // ---- 队列操作 ----
  String get editQueue => _t({'zh': '编辑队列', 'ja': 'キュー編集', 'en': 'Edit queue'});
  String get clearQueue => _t({'zh': '清空队列', 'ja': 'キューを空に', 'en': 'Clear queue'});
  String get customize => _t({'zh': '自定义', 'ja': 'カスタム', 'en': 'Custom'});

  // ---- 关于 ----
  String get about => _t({'zh': '关于', 'ja': 'このアプリについて', 'en': 'About'});
  String get aboutTitle => _t({'zh': '关于 Teigi', 'ja': 'Teigi について', 'en': 'About Teigi'});
  String get developer => _t({'zh': '开发者', 'ja': '開発者', 'en': 'Developer'});
  String get projectUrl => _t({'zh': '项目地址', 'ja': 'プロジェクト', 'en': 'Repository'});
  String get website => _t({'zh': '项目网站', 'ja': 'ウェブサイト', 'en': 'Website'});
  String get openSource => _t({'zh': '开源声明', 'ja': 'オープンソース', 'en': 'Open source'});
  String get openSourceDesc => _t({
        'zh': 'Teigi 是一款开源的桌面媒体转换工具，基于 Flutter 构建。\n核心功能依赖 ffmpeg。',
        'ja': 'Teigi は Flutter 製のオープンソースメディア変換ツールです。\n変換エンジンとして ffmpeg を使用します。',
        'en': 'Teigi is an open-source desktop media converter built with Flutter.\nIt relies on ffmpeg for conversion.',
      });

  // ---- 导入 ----
  String get importFolder =>
      _t({'zh': '导入文件夹', 'ja': 'フォルダを追加', 'en': 'Add Folder'});
  String get addFiles => _t({'zh': '添加文件', 'ja': 'ファイルを追加', 'en': 'Add Files'});
  String get chooseFolder =>
      _t({'zh': '选择文件夹', 'ja': 'フォルダを選択', 'en': 'Choose Folder'});
  String get chooseTargetFormat =>
      _t({'zh': '选择目标格式', 'ja': '出力形式を選択', 'en': 'Choose Target Format'});
  String get skip => _t({'zh': '跳过', 'ja': 'スキップ', 'en': 'Skip'});
  String get ok => _t({'zh': '确定', 'ja': 'OK', 'en': 'OK'});
  String get cancel => _t({'zh': '取消', 'ja': 'キャンセル', 'en': 'Cancel'});
  String get apply => _t({'zh': '应用', 'ja': '適用', 'en': 'Apply'});
  String get noFormatYet => _t({
        'zh': '暂不指定（可稍后逐个设置）',
        'ja': '未指定（後で個別設定可）',
        'en': 'Not now (set later)',
      });

  // ---- 队列 ----
  String queueCount(int n) =>
      _t({'zh': '转换队列（$n）', 'ja': '変換キュー（$n）', 'en': 'Queue ($n)'});
  String get start => _t({'zh': '开始转换', 'ja': '変換開始', 'en': 'Start'});
  String get converting => _t({'zh': '转换中…', 'ja': '変換中…', 'en': 'Converting…'});
  String get stop => _t({'zh': '停止', 'ja': '停止', 'en': 'Stop'});
  String get clear => _t({'zh': '清空', 'ja': 'クリア', 'en': 'Clear'});
  String get queueEmpty => _t({'zh': '队列为空', 'ja': 'キューは空です', 'en': 'Queue is empty'});
  String get queueEmptyHint => _t({
        'zh': '通过「添加文件」或拖拽文件到窗口导入媒体文件',
        'ja': '「ファイルを追加」またはドラッグ＆ドロップで追加できます',
        'en': 'Add files via the button or drag & drop',
      });
  String runningCount(int running, int queued) => _t({
        'zh': '运行中 $running · 等待 $queued',
        'ja': '実行中 $running · 待機 $queued',
        'en': 'Running $running · Queued $queued',
      });
  String missingFormatSkipped(int n) => _t({
        'zh': '有 $n 个任务未指定目标格式，已跳过',
        'ja': '$n 件のタスクが形式未指定のためスキップしました',
        'en': '$n task(s) skipped: no target format',
      });
  String get setFormatForAll =>
      _t({'zh': '统一格式', 'ja': '一括形式設定', 'en': 'Set Format'});

  // ---- 队列列表 ----
  String get noTargetFormat =>
      _t({'zh': '未指定目标格式', 'ja': '出力形式未指定', 'en': 'No target format'});
  String get moveUp => _t({'zh': '上移', 'ja': '上へ', 'en': 'Move up'});
  String get moveDown => _t({'zh': '下移', 'ja': '下へ', 'en': 'Move down'});
  String get configOptions => _t({'zh': '配置选项', 'ja': '設定', 'en': 'Options'});
  String get remove => _t({'zh': '移除', 'ja': '削除', 'en': 'Remove'});
  String get remainingLabel => _t({'zh': '剩余', 'ja': '残り', 'en': 'left'});
  String get failed => _t({'zh': '失败', 'ja': '失敗', 'en': 'Failed'});
  String get completed => _t({'zh': '完成', 'ja': '完了', 'en': 'Done'});
  String get canceled => _t({'zh': '已取消', 'ja': 'キャンセル済み', 'en': 'Canceled'});
  String get queued => _t({'zh': '等待中', 'ja': '待機中', 'en': 'Queued'});

  // ---- 格式 ----
  String get format => _t({'zh': '格式', 'ja': '形式', 'en': 'Format'});
  String get custom => _t({'zh': '自定义…', 'ja': 'カスタム…', 'en': 'Custom…'});
  String get customFormat =>
      _t({'zh': '自定义格式', 'ja': 'カスタム形式', 'en': 'Custom format'});
  String get customFormatHint => _t({
        'zh': '如 hevc、prores、ts、mkv',
        'ja': '例: hevc, prores, ts',
        'en': 'e.g. hevc, prores, ts',
      });
  String get saveAsQuick =>
      _t({'zh': '保存为快捷格式', 'ja': 'クイック形式に保存', 'en': 'Save as quick format'});
  String get savedAsQuick => _t({
        'zh': '已保存为快捷格式',
        'ja': 'クイック形式に保存しました',
        'en': 'Saved as quick format',
      });
  String get video => _t({'zh': '视频', 'ja': 'ビデオ', 'en': 'Video'});
  String get audio => _t({'zh': '音频', 'ja': 'オーディオ', 'en': 'Audio'});
  String get image => _t({'zh': '图片', 'ja': '画像', 'en': 'Image'});

  // ---- 配置选项 ----
  String get encoder => _t({'zh': '编码器', 'ja': 'エンコーダー', 'en': 'Encoder'});
  String get autoByFormat =>
      _t({'zh': '自动（按格式）', 'ja': '自動（形式に基づく）', 'en': 'Auto'});
  String get copyVideoStream =>
      _t({'zh': '视频流直接复制', 'ja': '映像ストリームをコピー', 'en': 'Copy video stream'});
  String get copyVideoHint => _t({
        'zh': '不重新编码，仅改封装',
        'ja': '再エンコードせず、カプセルのみ変更',
        'en': 'No re-encode, container only',
      });
  String get copyAudioStream =>
      _t({'zh': '音频流直接复制', 'ja': '音声ストリームをコピー', 'en': 'Copy audio stream'});
  String get qualityCrf => _t({'zh': '质量 (CRF)', 'ja': '品質 (CRF)', 'en': 'Quality (CRF)'});
  String get resolution => _t({'zh': '分辨率', 'ja': '解像度', 'en': 'Resolution'});
  String get frameRate => _t({'zh': '帧率', 'ja': 'フレームレート', 'en': 'Frame rate'});
  String get pixelFormat => _t({'zh': '像素格式', 'ja': 'ピクセル形式', 'en': 'Pixel format'});
  String get bitrate => _t({'zh': '比特率 (kbps)', 'ja': 'ビットレート (kbps)', 'en': 'Bitrate (kbps)'});
  String get sampleRate => _t({'zh': '采样率', 'ja': 'サンプリングレート', 'en': 'Sample rate'});
  String get channels => _t({'zh': '声道数', 'ja': 'チャンネル数', 'en': 'Channels'});
  String get volume => _t({'zh': '音量 (%)', 'ja': '音量 (%)', 'en': 'Volume (%)'});
  String get quality => _t({'zh': '质量', 'ja': '品質', 'en': 'Quality'});
  String get scale => _t({'zh': '缩放', 'ja': 'スケール', 'en': 'Scale'});
  String get maxResolution => _t({'zh': '最大分辨率', 'ja': '最大解像度', 'en': 'Max resolution'});
  String get keepOriginal => _t({'zh': '保持原始', 'ja': '元のまま', 'en': 'Original'});
  String get auto => _t({'zh': '自动', 'ja': '自動', 'en': 'Auto'});

  // ---- 设置 ----
  String get ffmpegPathTitle =>
      _t({'zh': '可执行文件路径', 'ja': '実行ファイルパス', 'en': 'Executable path'});
  String get usePathFfmpeg => _t({
        'zh': '使用系统 PATH 中的 ffmpeg',
        'ja': 'システム PATH の ffmpeg を使用',
        'en': 'Use ffmpeg from system PATH',
      });
  String get browse => _t({'zh': '浏览…', 'ja': '参照…', 'en': 'Browse…'});
  String get resetPathDetect =>
      _t({'zh': '恢复 PATH 检测', 'ja': 'PATH 検出に戻す', 'en': 'Use PATH detection'});
  String ffmpegReady(String v) =>
      _t({'zh': 'ffmpeg 已就绪：$v', 'ja': 'ffmpeg 利用可：$v', 'en': 'ffmpeg ready: $v'});
  String get ffmpegNotFound =>
      _t({'zh': '未找到 ffmpeg', 'ja': 'ffmpeg が見つかりません', 'en': 'ffmpeg not found'});
  String get redetect => _t({'zh': '重新检测', 'ja': '再検出', 'en': 'Re-detect'});
  String detectFailed(String e) => _t({
        'zh': 'ffmpeg 检测失败：$e',
        'ja': 'ffmpeg 検出失敗：$e',
        'en': 'ffmpeg detection failed: $e',
      });
  String get outputDirectory =>
      _t({'zh': '默认输出目录', 'ja': '既定の出力先', 'en': 'Output directory'});
  String get sameAsSource =>
      _t({'zh': '与源文件同目录', 'ja': '元と同じフォルダ', 'en': 'Same as source'});
  String get concurrency => _t({'zh': '并发转换数', 'ja': '並行変換数', 'en': 'Concurrency'});
  String concurrencyDesc(int n) => _t({
        'zh': '同时运行的 ffmpeg 进程数：$n',
        'ja': '同時に実行する ffmpeg プロセス数：$n',
        'en': 'Concurrent ffmpeg processes: $n',
      });
  String get hardwareAccel => _t({
        'zh': '默认启用硬件加速',
        'ja': 'ハードウェアアクセラレーション',
        'en': 'Hardware acceleration',
      });
  String get languageLabel => _t({'zh': '语言', 'ja': '言語', 'en': 'Language'});
  String get themeMode => _t({'zh': '主题模式', 'ja': 'テーマモード', 'en': 'Theme mode'});
  String get followSystem => _t({'zh': '跟随系统', 'ja': 'システムに従う', 'en': 'System'});
  String get lightMode => _t({'zh': '浅色', 'ja': 'ライト', 'en': 'Light'});
  String get darkMode => _t({'zh': '深色', 'ja': 'ダーク', 'en': 'Dark'});
  String get seedColor => _t({'zh': '种子颜色', 'ja': 'シードカラー', 'en': 'Seed color'});
  String get seedColorHint => _t({
        'zh': '输入十六进制色值或选择预设',
        'ja': 'HEX値を入力するかプリセットを選択',
        'en': 'Enter a hex value or pick a preset',
      });
  String get behaviors => _t({'zh': '行为', 'ja': '動作', 'en': 'Behavior'});
  String get openOutputAfterDone => _t({
        'zh': '完成后自动打开输出目录',
        'ja': '完了後、出力先を開く',
        'en': 'Open output folder after done',
      });
  String get conflictPolicy =>
      _t({'zh': '文件名冲突策略', 'ja': 'ファイル名競合時', 'en': 'Conflict policy'});
  String get keepBoth => _t({'zh': '保留两者', 'ja': '両方残す', 'en': 'Keep both'});
  String get overwrite => _t({'zh': '覆盖', 'ja': '上書き', 'en': 'Overwrite'});
  String get quickFormats =>
      _t({'zh': '快捷格式', 'ja': 'クイック形式', 'en': 'Quick formats'});
  String get quickFormatsShort =>
      _t({'zh': '★ 快捷', 'ja': '★ クイック', 'en': '★ Quick'});
  String get quickFormatsHint => _t({
        'zh': '自定义格式快捷选项，可在此删除',
        'ja': 'カスタム形式のショートカット。ここで削除できます',
        'en': 'Custom format shortcuts. Remove here.',
      });
  String get conversionSettings =>
      _t({'zh': '转换', 'ja': '変換', 'en': 'Conversion'});
  String get appearance => _t({'zh': '外观', 'ja': '外観', 'en': 'Appearance'});
}

/// 当前语言下的文案 Provider。
final l10nProvider = Provider<L10n>((ref) {
  final lang = ref.watch(settingsProvider).language;
  return L10n(L10n.supported.contains(lang) ? lang : 'zh');
});

