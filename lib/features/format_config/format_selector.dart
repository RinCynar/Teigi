import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/core/models/format_definitions.dart';
import 'package:teigi/i18n/strings.dart';
import 'package:teigi/providers/quick_formats_provider.dart';

/// 目标格式选择下拉框。
///
/// 排列规则：
/// 1. 快捷格式（用户自定义，含保存的配置）置顶
/// 2. 按类型分组：视频 / 音频 / 图片
/// 3. 「自定义…」手动输入任意扩展名（可保存为快捷格式）
class FormatSelector extends ConsumerStatefulWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  /// 选中快捷格式时，附带应用其保存的转码配置。
  final ValueChanged<ConversionOptions>? onQuickOptionsApplied;

  const FormatSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.onQuickOptionsApplied,
  });

  @override
  ConsumerState<FormatSelector> createState() => _FormatSelectorState();
}

class _FormatSelectorState extends ConsumerState<FormatSelector> {
  static const _customKey = '__custom__';
  static const _headerVideo = '__header_video__';
  static const _headerAudio = '__header_audio__';
  static const _headerImage = '__header_image__';
  static const _headerQuick = '__header_quick__';

  /// 弹出自定义格式输入对话框。
  Future<void> _askCustomFormat() async {
    final l10n = ref.read(l10nProvider);
    final controller = TextEditingController();
    var saveAsQuick = false;

    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.customFormat),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.customFormatHint,
                  prefixText: '.',
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.saveAsQuick),
                value: saveAsQuick,
                onChanged: (v) => setState(() => saveAsQuick = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: Text(l10n.ok),
            ),
          ],
        ),
      ),
    );
    if (entered == null) return;
    var ext = entered.trim().toLowerCase();
    if (ext.startsWith('.')) ext = ext.substring(1);
    if (ext.isEmpty) return;

    if (saveAsQuick) {
      await ref.read(quickFormatsProvider.notifier).add(ext);
    }
    widget.onChanged(ext);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final quickFormats = ref.watch(quickFormatsProvider);
    final scheme = Theme.of(context).colorScheme;

    // 当前值不在列表/内置中时，作为「快捷」项展示在最前。
    final quick = <QuickFormat>[...quickFormats];
    if (widget.value != null &&
        widget.value!.isNotEmpty &&
        !quick.any((f) => f.extension == widget.value) &&
        !builtinFormats.any((f) => f.extension == widget.value)) {
      quick.insert(
        0,
        QuickFormat(extension: widget.value!, options: const ConversionOptions()),
      );
    }

    final videoFormats =
        builtinFormats.where((f) => f.type == MediaType.video).toList();
    final audioFormats =
        builtinFormats.where((f) => f.type == MediaType.audio).toList();
    final imageFormats =
        builtinFormats.where((f) => f.type == MediaType.image).toList();

    Widget header(String text) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.primary),
          ),
        );

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: widget.value,
        hint: Text(l10n.format, style: const TextStyle(fontSize: 13)),
        isDense: true,
        style: Theme.of(context).textTheme.bodySmall,
        items: [
          if (quick.isNotEmpty) ...[
            DropdownMenuItem(
              value: _headerQuick,
              enabled: false,
              child: header(l10n.quickFormatsShort),
            ),
            for (final f in quick)
              DropdownMenuItem(
                value: f.extension,
                child: Text(f.extension.toUpperCase()),
              ),
          ],
          DropdownMenuItem(
            value: _headerVideo,
            enabled: false,
            child: header(l10n.video),
          ),
          for (final f in videoFormats)
            DropdownMenuItem(value: f.extension, child: Text(f.extension.toUpperCase())),
          DropdownMenuItem(
            value: _headerAudio,
            enabled: false,
            child: header(l10n.audio),
          ),
          for (final f in audioFormats)
            DropdownMenuItem(value: f.extension, child: Text(f.extension.toUpperCase())),
          DropdownMenuItem(
            value: _headerImage,
            enabled: false,
            child: header(l10n.image),
          ),
          for (final f in imageFormats)
            DropdownMenuItem(value: f.extension, child: Text(f.extension.toUpperCase())),
          DropdownMenuItem(
            value: _customKey,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, size: 14),
                const SizedBox(width: 4),
                Text(l10n.custom),
              ],
            ),
          ),
        ],
        onChanged: (v) {
          if (v == _customKey) {
            _askCustomFormat();
            return;
          }
          widget.onChanged(v);
          // 选中快捷格式时应用其保存的配置。
          if (v != null) {
            for (final f in quickFormats) {
              if (f.extension == v) {
                widget.onQuickOptionsApplied?.call(f.options);
                break;
              }
            }
          }
        },
      ),
    );
  }
}
