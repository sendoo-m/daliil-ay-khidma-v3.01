import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/search_history_repository.dart';

class SearchHistoryController extends StateNotifier<AsyncValue<List<String>>> {
  SearchHistoryController(this._repository)
      : super(const AsyncValue.loading()) {
    load();
  }

  final SearchHistoryRepository _repository;

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repository.load);
  }

  Future<void> add(String query) async {
    final previous = state.valueOrNull ?? const <String>[];
    final normalized = query.trim();
    if (normalized.isEmpty) return;
    state = AsyncValue.data(<String>[
      normalized,
      ...previous.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(SearchHistoryRepository.maxItems).toList(growable: false));
    state = await AsyncValue.guard(() => _repository.add(normalized));
  }

  Future<void> remove(String query) async {
    state = await AsyncValue.guard(() => _repository.remove(query));
  }

  Future<void> clear() async {
    await _repository.clear();
    state = const AsyncValue.data([]);
  }
}
