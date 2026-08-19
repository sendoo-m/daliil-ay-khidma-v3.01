import 'package:dalil_core/dalil_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final merchantThemeStoreProvider = Provider<DalilThemePreferenceStore>(
  (_) => DalilThemePreferenceStore(),
);

final merchantThemeControllerProvider =
    StateNotifierProvider<MerchantThemeController, DalilThemePreference>(
  (ref) => MerchantThemeController(ref.read(merchantThemeStoreProvider)),
);

class MerchantThemeController extends StateNotifier<DalilThemePreference> {
  MerchantThemeController(this._store) : super(const DalilThemePreference()) {
    _restore();
  }

  final DalilThemePreferenceStore _store;

  Future<void> _restore() async => state = await _store.read();

  Future<void> setPreset(DalilThemePreset preset) async {
    state = state.copyWith(preset: preset);
    await _store.write(state);
  }

  Future<void> setAppearance(DalilAppearance appearance) async {
    state = state.copyWith(appearance: appearance);
    await _store.write(state);
  }

  Future<void> setCustomColors(List<Color> colors) async {
    if (colors.length < 2 || colors.length > 3) {
      throw ArgumentError('Custom themes require two or three colors.');
    }
    state = state.copyWith(
      preset: DalilThemePreset.custom,
      customColors: List.unmodifiable(colors),
    );
    await _store.write(state);
  }
}
