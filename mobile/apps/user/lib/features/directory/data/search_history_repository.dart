import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SearchHistoryRepository {
  SearchHistoryRepository(this._storage);

  static const _storageKey = 'search_history_v3';
  static const maxItems = 8;

  final FlutterSecureStorage _storage;

  Future<List<String>> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(maxItems)
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  Future<List<String>> add(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return load();

    final current = await load();
    final updated = <String>[
      normalized,
      ...current.where(
        (item) => item.toLowerCase() != normalized.toLowerCase(),
      ),
    ].take(maxItems).toList(growable: false);

    await _storage.write(key: _storageKey, value: jsonEncode(updated));
    return updated;
  }

  Future<List<String>> remove(String query) async {
    final current = await load();
    final updated = current
        .where((item) => item.toLowerCase() != query.toLowerCase())
        .toList(growable: false);
    await _storage.write(key: _storageKey, value: jsonEncode(updated));
    return updated;
  }

  Future<void> clear() => _storage.delete(key: _storageKey);
}
