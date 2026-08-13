import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/core/models/conversion_options.dart';
import 'package:teigi/providers/settings_provider.dart';

/// 快捷格式：扩展名 + 关联的转码配置。
class QuickFormat {
  final String extension;
  final ConversionOptions options;

  const QuickFormat({required this.extension, required this.options});

  Map<String, dynamic> toJson() => {
        'ext': extension,
        'opts': options.toJson(),
      };

  static QuickFormat fromJson(Map<String, dynamic> json) => QuickFormat(
        extension: json['ext'] as String? ?? '',
        options: ConversionOptions.fromJson(
          json['opts'] as Map<String, dynamic>? ?? const {},
        ),
      );
}

/// 自定义快捷格式（扩展名 + 配置，持久化到 shared_preferences）。
class QuickFormatsNotifier extends StateNotifier<List<QuickFormat>> {
  QuickFormatsNotifier(super.initial, this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'quick_formats_v2';

  static List<QuickFormat> load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list)
          QuickFormat.fromJson((item as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode([for (final f in state) f.toJson()]),
    );
  }

  /// 添加快捷格式（按扩展名去重，已存在则更新配置）。
  Future<void> add(String ext, {ConversionOptions? options}) async {
    final normalized = ext.toLowerCase();
    if (normalized.isEmpty) return;
    final existing = state.indexWhere((f) => f.extension == normalized);
    if (existing >= 0) {
      state = [
        for (var i = 0; i < state.length; i++)
          if (i == existing)
            QuickFormat(
              extension: normalized,
              options: options ?? state[i].options,
            )
          else
            state[i],
      ];
    } else {
      state = [
        ...state,
        QuickFormat(extension: normalized, options: options ?? const ConversionOptions()),
      ];
    }
    await _persist();
  }

  /// 更新某个快捷格式的配置。
  Future<void> updateOptions(String ext, ConversionOptions options) =>
      add(ext, options: options);

  /// 移除快捷格式。
  Future<void> remove(String ext) async {
    state = state.where((f) => f.extension != ext).toList();
    await _persist();
  }

  /// 根据扩展名查找快捷格式。
  QuickFormat? find(String ext) {
    for (final f in state) {
      if (f.extension == ext) return f;
    }
    return null;
  }
}

/// 快捷格式 Provider。
final quickFormatsProvider =
    StateNotifierProvider<QuickFormatsNotifier, List<QuickFormat>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return QuickFormatsNotifier(QuickFormatsNotifier.load(prefs), prefs);
});
