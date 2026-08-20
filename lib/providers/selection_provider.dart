import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected workspace task ids. Not stored on [ConversionTask].
class SelectionNotifier extends StateNotifier<Set<String>> {
  SelectionNotifier() : super(const {});

  void clear() => state = const {};

  void selectOnly(String id) => state = {id};

  void toggle(String id) {
    final next = {...state};
    if (!next.add(id)) next.remove(id);
    state = next;
  }

  void selectRange(List<String> orderedIds, String fromId, String toId) {
    final a = orderedIds.indexOf(fromId);
    final b = orderedIds.indexOf(toId);
    if (a < 0 || b < 0) {
      selectOnly(toId);
      return;
    }
    final start = a < b ? a : b;
    final end = a < b ? b : a;
    state = orderedIds.sublist(start, end + 1).toSet();
  }

  void handleClick(
    String id, {
    required List<String> orderedIds,
    required bool ctrl,
    required bool shift,
    String? anchorId,
  }) {
    if (shift && anchorId != null) {
      selectRange(orderedIds, anchorId, id);
      return;
    }
    if (ctrl || state.length > 1 || (state.length == 1 && state.contains(id))) {
      toggle(id);
      return;
    }
    selectOnly(id);
  }

  void selectAll(Iterable<String> ids) => state = ids.toSet();

  void remove(String id) {
    if (!state.contains(id)) return;
    final next = {...state}..remove(id);
    state = next;
  }
}

final selectionProvider =
    StateNotifierProvider<SelectionNotifier, Set<String>>((ref) {
  return SelectionNotifier();
});
