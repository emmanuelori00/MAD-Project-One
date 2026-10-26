import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const equipmentChoices = [
  'No preference',
  'No equipment',
  'Dumbbells',
  'Resistance band',
  'Other',
];

class AppSettings {
  const AppSettings({
    this.equipment = 'No preference',
    this.defaultEffort = 3,
    this.reducedMotion = false,
  });

  final String equipment;
  final int defaultEffort;
  final bool reducedMotion;

  bool get isValid =>
      equipmentChoices.contains(equipment) &&
      defaultEffort >= 1 &&
      defaultEffort <= 5;

  String encode() => jsonEncode({
    'equipment': equipment,
    'defaultEffort': defaultEffort,
    'reducedMotion': reducedMotion,
  });

  factory AppSettings.decode(String text) {
    final value = jsonDecode(text) as Map<String, dynamic>;
    final result = AppSettings(
      equipment: value['equipment'] as String,
      defaultEffort: value['defaultEffort'] as int,
      reducedMotion: value['reducedMotion'] as bool,
    );
    if (!result.isValid) throw const FormatException('Invalid settings');
    return result;
  }
}

abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class PreferencesSettingsStore implements SettingsStore {
  PreferencesSettingsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;
  static const key = 'movement_quest.settings.v1';

  @override
  Future<AppSettings> load() async {
    final text = await _preferences.getString(key);
    return text == null ? const AppSettings() : AppSettings.decode(text);
  }

  @override
  Future<void> save(AppSettings settings) async {
    if (!settings.isValid) throw ArgumentError('Invalid settings');
    // One value prevents a partial save of the three preferences.
    await _preferences.setString(key, settings.encode());
  }
}

class SettingsController extends ChangeNotifier {
  SettingsController(this.store);

  final SettingsStore store;
  AppSettings value = const AppSettings();
  bool loaded = false;
  bool busy = false;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final saved = await store.load();
      if (_disposed) return;
      value = saved;
      loaded = true;
    } catch (_) {
      if (_disposed) return;
      error = 'Could not load your settings. Try again.';
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(AppSettings settings) async {
    if (busy || !loaded || !settings.isValid) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await store.save(settings);
      if (_disposed) return false;
      value = settings;
      return true;
    } catch (_) {
      if (!_disposed) {
        error = 'Could not save settings. Your old settings still apply.';
      }
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
