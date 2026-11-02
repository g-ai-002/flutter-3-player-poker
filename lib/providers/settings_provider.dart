import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage)
    : _darkMode = _storage.darkMode,
      _aiSpeed = _storage.aiSpeed,
      _aiLevel = _storage.aiLevel,
      _soundEnabled = _storage.soundEnabled,
      _musicEnabled = _storage.musicEnabled {
    AudioService.instance
      ..setSoundEnabled(_soundEnabled)
      ..setMusicEnabled(_musicEnabled);
  }

  final StorageService _storage;
  bool _darkMode;
  AiSpeed _aiSpeed;
  AiLevel _aiLevel;
  bool _soundEnabled;
  bool _musicEnabled;

  bool get darkMode => _darkMode;
  AiSpeed get aiSpeed => _aiSpeed;
  AiLevel get aiLevel => _aiLevel;
  bool get soundEnabled => _soundEnabled;
  bool get musicEnabled => _musicEnabled;

  void setDarkMode(bool value) {
    if (_darkMode == value) return;
    _darkMode = value;
    notifyListeners();
    _storage.setDarkMode(value);
  }

  void setAiSpeed(AiSpeed value) {
    if (_aiSpeed == value) return;
    _aiSpeed = value;
    notifyListeners();
    _storage.setAiSpeed(value);
  }

  void setAiLevel(AiLevel value) {
    if (_aiLevel == value) return;
    _aiLevel = value;
    notifyListeners();
    _storage.setAiLevel(value);
  }

  void setSoundEnabled(bool value) {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    AudioService.instance.setSoundEnabled(value);
    notifyListeners();
    _storage.setSoundEnabled(value);
  }

  void setMusicEnabled(bool value) {
    if (_musicEnabled == value) return;
    _musicEnabled = value;
    AudioService.instance.setMusicEnabled(value);
    notifyListeners();
    _storage.setMusicEnabled(value);
  }
}
