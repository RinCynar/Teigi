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
  String get navConvert => _t({'zh': '转换', 'ja': '変換', 'en': 'Convert'});
  String get navQueue => _t({'zh': '队列', 'ja': 'キュー', 'en': 'Queue'});
  String get navPresets => _t({'zh': '预设', 'ja': 'プリセット', 'en': 'Presets'});
  String get navSettings => _t({'zh': '设置', 'ja': '設定', 'en': 'Settings'});
  String get menu => _t({'zh': '菜单', 'ja': 'メニュー', 'en': 'Menu'});
  String get convertTitle => _t({'zh': '转换', 'ja': '変換', 'en': 'Convert'});
  String get convertSubtitle =>
      _t({'zh': '转换你的媒体', 'ja': 'メディアを変換', 'en': 'Convert your media'});
  String get dropToStart => _t({
    'zh': '把文件拖到这里开始',
    'ja': 'ファイルをドロップして開始',
    'en': 'Drop files here to get started',
  });
  String get dropFiles =>
      _t({'zh': '将文件拖到这里', 'ja': 'ファイルをドロップ', 'en': 'Drop files here'});
  String get dropHint => _t({
    'zh': '也可以把文件拖到这里',
    'ja': 'ここにドラッグしても追加できます',
    'en': 'You can also drag files here',
  });
  String get dropFilesAnywhere => _t({
    'zh': '也可拖放到窗口任意位置',
    'ja': 'ウィンドウのどこへでもドロップできます',
    'en': 'Drop files anywhere',
  });
  String get releaseToAdd =>
      _t({'zh': '松开以添加', 'ja': '離して追加', 'en': 'Release to add media'});
  String fileCount(int n) =>
      _t({'zh': '$n 个文件', 'ja': '$n 件', 'en': n == 1 ? '1 file' : '$n files'});
  String get output => _t({'zh': '输出', 'ja': '出力', 'en': 'Output'});
  String get qualityHigh => _t({'zh': '高', 'ja': '高', 'en': 'High'});
  String get qualityBalanced =>
      _t({'zh': '均衡', 'ja': 'バランス', 'en': 'Balanced'});
  String get qualitySmall => _t({'zh': '体积', 'ja': '軽量', 'en': 'Small'});
  String get recommendedConversion =>
      _t({'zh': '推荐转换', 'ja': 'おすすめの変換', 'en': 'Recommended conversion'});
  String get useThis => _t({'zh': '使用此方案', 'ja': 'これを使う', 'en': 'Use this'});
  String get checkingFfmpeg => _t({
    'zh': '正在检测 FFmpeg…',
    'ja': 'FFmpeg を確認中…',
    'en': 'Checking FFmpeg…',
  });
  String get ffmpegNotConfigured => _t({
    'zh': '尚未配置 FFmpeg',
    'ja': 'FFmpeg が未設定です',
    'en': "FFmpeg isn't configured",
  });
  String get advanced => _t({'zh': '高级', 'ja': '詳細', 'en': 'Advanced'});
  String get chooseFormat =>
      _t({'zh': '选择输出格式', 'ja': '出力形式を選択', 'en': 'Choose output format'});
  String get searchFormats =>
      _t({'zh': '搜索格式…', 'ja': '形式を検索…', 'en': 'Search formats...'});
  String get other => _t({'zh': '其他', 'ja': 'その他', 'en': 'Other'});
  String get customExtension =>
      _t({'zh': '自定义扩展名', 'ja': 'カスタム拡張子', 'en': 'Custom extension'});
  String get selectAll => _t({'zh': '全选', 'ja': 'すべて選択', 'en': 'Select all'});
  String selectedCount(int n) =>
      _t({'zh': '已选 $n 项', 'ja': '$n 件選択', 'en': '$n selected'});
  String applyToFiles(int n) =>
      _t({'zh': '应用到 $n 个文件', 'ja': '$n 件に適用', 'en': 'Apply to $n files'});
  String configureNFiles(int n) =>
      _t({'zh': '配置 $n 个文件', 'ja': '$n 件を設定', 'en': 'Configure $n files'});
  String get targetFormat =>
      _t({'zh': '目标格式', 'ja': '出力形式', 'en': 'Target format'});
  String get unchanged => _t({'zh': '保持原值', 'ja': '変更しない', 'en': 'Unchanged'});
  String get setValue => _t({'zh': '设为', 'ja': '設定', 'en': 'Set'});
  String get encoding => _t({'zh': '编码', 'ja': 'エンコード', 'en': 'Encoding'});
  String get reencode => _t({'zh': '重新编码', 'ja': '再エンコード', 'en': 'Re-encode'});
  String get copyStreamHint => _t({
    'zh': '不重新编码，只改封装',
    'ja': '再エンコードせずカプセルのみ変更',
    'en': 'No re-encoding will be performed.',
  });
  String get original => _t({'zh': '原始', 'ja': '元のまま', 'en': 'Original'});
  String get startReady =>
      _t({'zh': '只转换已就绪的', 'ja': '準備できたものだけ開始', 'en': 'Start ready files'});
  String get reviewMissing =>
      _t({'zh': '查看未配置', 'ja': '未設定を確認', 'en': 'Review'});
  String missingOutput(int n) => _t({
    'zh': '有 $n 个文件还没有输出格式。',
    'ja': '$n 件に出力形式がありません。',
    'en': '$n files are missing an output format.',
  });
  String readySummary(int total, int ready, int missing) => _t({
    'zh': '$total 个文件 · $ready 已就绪 · $missing 需配置',
    'ja': '$total 件 · 準備 $ready · 要設定 $missing',
    'en': '$total files · $ready ready · $missing need configuration',
  });
  String get clearCompleted =>
      _t({'zh': '清除已完成', 'ja': '完了を削除', 'en': 'Clear completed'});
  String get filterAll => _t({'zh': '全部', 'ja': 'すべて', 'en': 'All'});
  String get filterActive => _t({'zh': '进行中', 'ja': '実行中', 'en': 'Active'});
  String get openFile => _t({'zh': '打开文件', 'ja': 'ファイルを開く', 'en': 'Open file'});
  String get openFolder =>
      _t({'zh': '打开文件夹', 'ja': 'フォルダを開く', 'en': 'Open folder'});
  String get viewLog => _t({'zh': '查看日志', 'ja': 'ログ', 'en': 'View log'});
  String get saveAsPreset =>
      _t({'zh': '保存为预设', 'ja': 'プリセットに保存', 'en': 'Save as preset'});
  String get createPreset =>
      _t({'zh': '创建预设', 'ja': 'プリセットを作成', 'en': 'Create preset'});
  String get general => _t({'zh': '常规', 'ja': '一般', 'en': 'General'});
  String get kbps => _t({'zh': 'kbps', 'ja': 'kbps', 'en': 'kbps'});
  String get customValue => _t({'zh': '自定义数值', 'ja': '数値を指定', 'en': 'Custom'});
  String get queueIdleHint => _t({
    'zh': '任务会在开始转换后出现在这里',
    'ja': '変換を始めるとここに表示されます',
    'en': 'Tasks show up here after you start converting',
  });
  String presetWillApply(String name) => _t({
    'zh': '接下来添加的文件将使用 $name',
    'ja': '次に追加するファイルは $name になります',
    'en': 'Next files will use $name',
  });
  String get supportedFormats => _t({
    'zh': 'MP4 · MKV · MOV · MP3 · WAV · PNG · WebP',
    'ja': 'MP4 · MKV · MOV · MP3 · WAV · PNG · WebP',
    'en': 'MP4 · MKV · MOV · MP3 · WAV · PNG · WebP',
  });
  String get startConversion =>
      _t({'zh': '开始转换', 'ja': '変換を開始', 'en': 'Start conversion'});
  String get recentPresets => _t({'zh': '最近使用', 'ja': '最近', 'en': 'Recent'});
  String get recommended => _t({'zh': '推荐', 'ja': 'おすすめ', 'en': 'Recommended'});
  String get configure => _t({'zh': '配置', 'ja': '設定', 'en': 'Configure'});
  String get retry => _t({'zh': '重试', 'ja': '再試行', 'en': 'Retry'});
  String get filesHeading => _t({'zh': '文件', 'ja': 'ファイル', 'en': 'Files'});
  String filesAdded(int n) =>
      _t({'zh': '已添加 $n 个文件', 'ja': '$n 件追加しました', 'en': '$n file(s) added'});
  String get builtinPresets =>
      _t({'zh': '内置预设', 'ja': '内蔵プリセット', 'en': 'Built-in presets'});
  String get myPresets =>
      _t({'zh': '我的预设', 'ja': 'マイプリセット', 'en': 'My presets'});
  String get presetsEmpty => _t({
    'zh': '还没有自定义预设。在配置里保存即可出现在这里。',
    'ja': 'カスタムプリセットはまだありません。',
    'en': 'No custom presets yet. Save one from Configure.',
  });
  String get hardwareAccelHint => _t({
    'zh': '有益时使用硬件编码',
    'ja': '有効な場合にハードウェアエンコードを使います',
    'en': 'Uses hardware encoding when beneficial.',
  });
  String get ffmpegMissingBody => _t({
    'zh': '未找到 FFmpeg。请指定路径，或安装后再试。',
    'ja': 'FFmpeg が見つかりません。パスを指定するか、インストールしてください。',
    'en': "FFmpeg isn't installed. Locate it, or install it first.",
  });
  String get locateFfmpeg =>
      _t({'zh': '定位 FFmpeg', 'ja': 'FFmpeg を指定', 'en': 'Locate FFmpeg'});
  String conversionPair(String from, String to) =>
      '${from.toUpperCase()} → ${to.toUpperCase()}';

  // ---- 队列操作 ----
  String get editQueue => _t({'zh': '编辑队列', 'ja': 'キュー編集', 'en': 'Edit queue'});
  String get clearQueue =>
      _t({'zh': '清空队列', 'ja': 'キューを空に', 'en': 'Clear queue'});
  String get customize => _t({'zh': '自定义', 'ja': 'カスタム', 'en': 'Custom'});

  // ---- 关于 ----
  String get about => _t({'zh': '关于', 'ja': 'このアプリについて', 'en': 'About'});
  String get aboutTitle =>
      _t({'zh': '关于 Teigi', 'ja': 'Teigi について', 'en': 'About Teigi'});
  String get developer => _t({'zh': '开发者', 'ja': '開発者', 'en': 'Developer'});
  String get projectUrl =>
      _t({'zh': '项目地址', 'ja': 'プロジェクト', 'en': 'Repository'});
  String get website => _t({'zh': '项目网站', 'ja': 'ウェブサイト', 'en': 'Website'});
  String get openSource =>
      _t({'zh': '开源声明', 'ja': 'オープンソース', 'en': 'Open source'});
  String get openSourceDesc => _t({
    'zh': 'Teigi 是一款开源的桌面媒体转换工具，基于 Flutter 构建。\n核心功能依赖 ffmpeg。',
    'ja': 'Teigi は Flutter 製のオープンソースメディア変換ツールです。\n変換エンジンとして ffmpeg を使用します。',
    'en':
        'Teigi is an open-source desktop media converter built with Flutter.\nIt relies on ffmpeg for conversion.',
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
  String get converting =>
      _t({'zh': '转换中…', 'ja': '変換中…', 'en': 'Converting…'});
  String get stop => _t({'zh': '停止', 'ja': '停止', 'en': 'Stop'});
  String get clear => _t({'zh': '清空', 'ja': 'クリア', 'en': 'Clear'});
  String get queueEmpty =>
      _t({'zh': '队列为空', 'ja': 'キューは空です', 'en': 'Queue is empty'});
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
  String get qualityCrf =>
      _t({'zh': '质量 (CRF)', 'ja': '品質 (CRF)', 'en': 'Quality (CRF)'});
  String get resolution => _t({'zh': '分辨率', 'ja': '解像度', 'en': 'Resolution'});
  String get frameRate => _t({'zh': '帧率', 'ja': 'フレームレート', 'en': 'Frame rate'});
  String get pixelFormat =>
      _t({'zh': '像素格式', 'ja': 'ピクセル形式', 'en': 'Pixel format'});
  String get bitrate =>
      _t({'zh': '比特率 (kbps)', 'ja': 'ビットレート (kbps)', 'en': 'Bitrate (kbps)'});
  String get sampleRate =>
      _t({'zh': '采样率', 'ja': 'サンプリングレート', 'en': 'Sample rate'});
  String get channels => _t({'zh': '声道数', 'ja': 'チャンネル数', 'en': 'Channels'});
  String get volume => _t({'zh': '音量 (%)', 'ja': '音量 (%)', 'en': 'Volume (%)'});
  String get quality => _t({'zh': '质量', 'ja': '品質', 'en': 'Quality'});
  String get scale => _t({'zh': '缩放', 'ja': 'スケール', 'en': 'Scale'});
  String get maxResolution =>
      _t({'zh': '最大分辨率', 'ja': '最大解像度', 'en': 'Max resolution'});
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
  String get useBundledFfmpeg => _t({
    'zh': '使用安装目录内置的 ffmpeg',
    'ja': 'インストール先に内蔵された ffmpeg を使用',
    'en': 'Use the ffmpeg bundled with the installation',
  });
  String get browse => _t({'zh': '浏览…', 'ja': '参照…', 'en': 'Browse…'});
  String get resetPathDetect =>
      _t({'zh': '恢复 PATH 检测', 'ja': 'PATH 検出に戻す', 'en': 'Use PATH detection'});
  String get customPathInvalid => _t({
    'zh': '自定义路径无效',
    'ja': 'カスタムパスが無効です',
    'en': 'Custom executable path is invalid',
  });
  String get customPathInvalidUsingBundled => _t({
    'zh': '自定义路径无效，已使用内置版本',
    'ja': 'カスタムパスが無効なため、内蔵版を使用しています',
    'en': 'Custom executable path is invalid; using the bundled version',
  });
  String get customPathInvalidUsingPath => _t({
    'zh': '自定义路径无效，已使用系统 PATH 中的版本',
    'ja': 'カスタムパスが無効なため、システム PATH の版を使用しています',
    'en': 'Custom executable path is invalid; using the system PATH version',
  });
  String ffmpegReady(String v) => _t({
    'zh': 'ffmpeg 已就绪：$v',
    'ja': 'ffmpeg 利用可：$v',
    'en': 'ffmpeg ready: $v',
  });
  String get ffmpegNotFound => _t({
    'zh': '未找到 ffmpeg',
    'ja': 'ffmpeg が見つかりません',
    'en': 'ffmpeg not found',
  });
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
  String get concurrency =>
      _t({'zh': '并发转换数', 'ja': '並行変換数', 'en': 'Concurrency'});
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
  String get themeMode =>
      _t({'zh': '主题模式', 'ja': 'テーマモード', 'en': 'Theme mode'});
  String get followSystem =>
      _t({'zh': '跟随系统', 'ja': 'システムに従う', 'en': 'System'});
  String get lightMode => _t({'zh': '浅色', 'ja': 'ライト', 'en': 'Light'});
  String get darkMode => _t({'zh': '深色', 'ja': 'ダーク', 'en': 'Dark'});
  String get seedColor =>
      _t({'zh': '种子颜色', 'ja': 'シードカラー', 'en': 'Seed color'});
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
