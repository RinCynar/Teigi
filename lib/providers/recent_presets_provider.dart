import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teigi/core/models/format_preset.dart';
import 'package:teigi/providers/settings_provider.dart';

/// Last-used built-in preset ids, newest first.
class RecentPresetsNotifier extends StateNotifier<List<String>> {
  RecentPresetsNotifier(super.initial, this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'recent_preset_ids';
  static const _max = 5;

  static List<String> load(SharedPreferences prefs) {
    return prefs.getStringList(_key) ?? const [];
  }

  Future<void> record(String id) async {
    final next = [id, ...state.where((e) => e != id)].take(_max).toList();
    state = next;
    await _prefs.setStringList(_key, next);
  }

  List<FormatPreset> get presets {
    return [
      for (final id in state)
        if (FormatPreset.byId(id) != null) FormatPreset.byId(id)!,
    ];
  }
}

final recentPresetsProvider =
    StateNotifierProvider<RecentPresetsNotifier, List<String>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RecentPresetsNotifier(RecentPresetsNotifier.load(prefs), prefs);
});
