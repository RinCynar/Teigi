import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/conversion_task.dart';
import 'package:teigi/core/models/format_definitions.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/queue_provider.dart';
import 'package:teigi/providers/quick_formats_provider.dart';

/// 转码参数配置编辑器（弹层）。
///
/// 根据目标格式类型动态展示配置项：
/// - 视频：编码器 / CRF / 分辨率 / 帧率 / 像素格式 / 流复制
/// - 音频：编码器 / 比特率(可输入) / 采样率 / 声道 / 音量 / 流复制
/// - 图片：质量 / 缩放 / 最大分辨率
///
/// 硬件加速、并发、覆盖策略等为全局设置，不在此配置。
class OptionsEditor extends ConsumerWidget {
  final ConversionTask task;

  const OptionsEditor({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.configOptions,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.apply),
                ),
              ],
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  OptionsForm(
                    targetFormat: task.targetFormat,
                    initial: task.options,
                    onChanged: (o) =>
                        ref.read(queueProvider.notifier).setOptions(task.id, o),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 可复用的转码参数表单（供任务编辑器、导入对话框共用）。
class OptionsForm extends ConsumerStatefulWidget {
  final String? targetFormat;
  final ConversionOptions initial;
  final ValueChanged<ConversionOptions> onChanged;

  const OptionsForm({
    super.key,
    required this.targetFormat,
    required this.initial,
    required this.onChanged,
  });

  @override
  ConsumerState<OptionsForm> createState() => _OptionsFormState();
}

class _OptionsFormState extends ConsumerState<OptionsForm> {
  late ConversionOptions _options;

  /// 自定义格式（无内置类型）时用户选择的媒体类型。
  MediaType? _mediaTypeOverride;

  @override
  void initState() {
    super.initState();
    _options = widget.initial;
  }

  /// 目标格式是否内置；null 表示未知/自定义格式。
  FormatDefinition? get _builtin {
    final fmt = widget.targetFormat;
    return fmt == null ? null : findBuiltinFormat(fmt);
  }

  MediaType get _effectiveType {
    final builtin = _builtin;
    if (builtin != null) return builtin.type;
    return _mediaTypeOverride ?? MediaType.video;
  }

  void _update(ConversionOptions updated) {
    setState(() => _options = updated);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final isCustom = widget.targetFormat != null && _builtin == null;
    final type = _effectiveType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 自定义格式：让用户选择媒体类型以展示对应配置。
        if (isCustom) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: SegmentedButton<MediaType>(
              segments: [
                ButtonSegment(value: MediaType.video, label: Text(l10n.video)),
                ButtonSegment(value: MediaType.audio, label: Text(l10n.audio)),
                ButtonSegment(value: MediaType.image, label: Text(l10n.image)),
              ],
              selected: {type},
              onSelectionChanged: (s) =>
                  setState(() => _mediaTypeOverride = s.first),
            ),
          ),
        ],
        if (widget.targetFormat != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final fmt = widget.targetFormat!;
                await ref
                    .read(quickFormatsProvider.notifier)
                    .updateOptions(fmt, _options);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.savedAsQuick)),
                  );
                }
              },
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: Text(l10n.saveAsQuick),
            ),
          ),
        if (type == MediaType.video) _videoSection(context),
        if (type == MediaType.audio) _audioSection(context),
        if (type == MediaType.image) _imageSection(context),
      ],
    );
  }

  // ---------------- 视频 ----------------
  Widget _videoSection(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return _Section(
      title: l10n.video,
      children: [
        _OptionDropdown(
          label: l10n.encoder,
          value: _options.videoEncoder,
          hint: l10n.autoByFormat,
          items: const [
            'libx264', 'libx265', 'libvpx-vp9', 'mpeg4', 'h264_nvenc', 'hevc_nvenc',
          ],
          onChanged: (v) => _update(_options.copyWith(videoEncoder: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.copyVideoStream),
          subtitle: Text(l10n.copyVideoHint),
          value: _options.copyVideo,
          onChanged: (v) => _update(_options.copyWith(copyVideo: v)),
        ),
        if (!_options.copyVideo) ...[
          _OptionSlider(
            label: l10n.qualityCrf,
            value: (_options.crf ?? 23).toDouble(),
            min: 0,
            max: 51,
            divisions: 51,
            display: (_options.crf ?? 23).toString(),
            onChanged: (v) => _update(_options.copyWith(crf: v.round())),
          ),
          _OptionTextField(
            label: l10n.resolution,
            value: _options.resolution,
            hint: '1920x1080',
            onChanged: (v) => _update(_options.copyWith(resolution: v)),
          ),
          _OptionDropdown(
            label: l10n.frameRate,
            value: _options.frameRate?.toString(),
            hint: l10n.keepOriginal,
            items: const ['24', '25', '30', '48', '60'],
            onChanged: (v) => _update(
              _options.copyWith(frameRate: v == null ? null : double.tryParse(v)),
            ),
          ),
          _OptionDropdown(
            label: l10n.pixelFormat,
            value: _options.pixelFormat,
            hint: l10n.auto,
            items: const ['yuv420p', 'yuv422p', 'yuv444p', 'rgb24'],
            onChanged: (v) => _update(_options.copyWith(pixelFormat: v)),
          ),
        ],
      ],
    );
  }

  // ---------------- 音频 ----------------
  Widget _audioSection(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return _Section(
      title: l10n.audio,
      children: [
        _OptionDropdown(
          label: l10n.encoder,
          value: _options.audioEncoder,
          hint: l10n.autoByFormat,
          items: const [
            'aac', 'libmp3lame', 'libopus', 'libvorbis', 'flac', 'pcm_s16le',
          ],
          onChanged: (v) => _update(_options.copyWith(audioEncoder: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.copyAudioStream),
          value: _options.copyAudio,
          onChanged: (v) => _update(_options.copyWith(copyAudio: v)),
        ),
        if (!_options.copyAudio) ...[
          _OptionNumberField(
            label: l10n.bitrate,
            value: _options.bitrateKbps,
            hint: '192',
            onChanged: (v) => _update(_options.copyWith(bitrateKbps: v)),
          ),
          _OptionDropdown(
            label: l10n.sampleRate,
            value: _options.sampleRate?.toString(),
            hint: l10n.auto,
            items: const ['22050', '32000', '44100', '48000', '96000'],
            onChanged: (v) => _update(
              _options.copyWith(sampleRate: v == null ? null : int.tryParse(v)),
            ),
          ),
          _OptionDropdown(
            label: l10n.channels,
            value: _options.channels?.toString(),
            hint: l10n.auto,
            items: const ['1', '2', '6', '8'],
            onChanged: (v) => _update(
              _options.copyWith(channels: v == null ? null : int.tryParse(v)),
            ),
          ),
          _OptionSlider(
            label: l10n.volume,
            value: (_options.volume ?? 100).toDouble(),
            min: 0,
            max: 200,
            divisions: 40,
            display: (_options.volume ?? 100).toString(),
            onChanged: (v) => _update(_options.copyWith(volume: v.round())),
          ),
        ],
      ],
    );
  }

  // ---------------- 图片 ----------------
  Widget _imageSection(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return _Section(
      title: l10n.image,
      children: [
        _OptionSlider(
          label: l10n.quality,
          value: (_options.imageQuality ?? 90).toDouble(),
          min: 1,
          max: 100,
          divisions: 99,
          display: (_options.imageQuality ?? 90).toString(),
          onChanged: (v) => _update(_options.copyWith(imageQuality: v.round())),
        ),
        _OptionDropdown(
          label: l10n.scale,
          value: _options.imageScale,
          hint: l10n.keepOriginal,
          items: const ['25%', '50%', '75%', '150%', '200%'],
          onChanged: (v) => _update(_options.copyWith(imageScale: v)),
        ),
        _OptionTextField(
          label: l10n.maxResolution,
          value: _options.maxResolution,
          hint: '1920x1080',
          onChanged: (v) => _update(_options.copyWith(maxResolution: v)),
        ),
      ],
    );
  }
}


/// 配置分组。
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        ...children,
      ],
    );
  }
}

/// 选项下拉框（支持 null 表示「自动」）。
class _OptionDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String? hint;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? labelFor;

  const _OptionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      trailing: DropdownButton<T>(
        value: value,
        isDense: true,
        hint: hint == null ? null : Text(hint!),
        items: [
          if (hint != null)
            DropdownMenuItem<T>(
              value: null,
              child: Text(
                hint!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          for (final item in items)
            DropdownMenuItem<T>(
              value: item,
              child: Text(labelFor != null ? labelFor!(item) : item.toString()),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// 选项滑杆。
class _OptionSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _OptionSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            Text(display, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}


/// 数值输入行（支持直接输入指定数值，留空表示自动）。
class _OptionNumberField extends ConsumerStatefulWidget {
  final String label;
  final int? value;
  final String? hint;
  final ValueChanged<int?> onChanged;

  const _OptionNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  @override
  ConsumerState<_OptionNumberField> createState() => _OptionNumberFieldState();
}

class _OptionNumberFieldState extends ConsumerState<_OptionNumberField> {
  late final TextEditingController _controller;
  late bool _auto;

  @override
  void initState() {
    super.initState();
    _auto = widget.value == null;
    _controller = TextEditingController(
      text: widget.value?.toString() ?? widget.hint ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final v = int.tryParse(_controller.text.trim());
    widget.onChanged(_auto ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(widget.label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 按钮语义：点击后启用自定义输入。
          Text(l10n.customize, style: Theme.of(context).textTheme.bodySmall),
          Switch(
            value: !_auto,
            onChanged: (v) {
              setState(() => _auto = !v);
              if (_auto) {
                widget.onChanged(null);
              } else {
                _commit();
              }
            },
          ),
          SizedBox(
            width: 88,
            child: TextField(
              controller: _controller,
              enabled: !_auto,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.hint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _commit(),
              onChanged: (_) => _commit(),
            ),
          ),
        ],
      ),
    );
  }
}


/// 文本输入行（支持自由填写，留空表示不指定）。
class _OptionTextField extends StatefulWidget {
  final String label;
  final String? value;
  final String? hint;
  final ValueChanged<String?> onChanged;

  const _OptionTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  @override
  State<_OptionTextField> createState() => _OptionTextFieldState();
}

class _OptionTextFieldState extends State<_OptionTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final v = _controller.text.trim();
    widget.onChanged(v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(widget.label),
      trailing: SizedBox(
        width: 140,
        child: TextField(
          controller: _controller,
          textAlign: TextAlign.end,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commit(),
          onChanged: (_) => _commit(),
        ),
      ),
    );
  }
}

