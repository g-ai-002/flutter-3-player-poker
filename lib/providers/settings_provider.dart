import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage)
    : _darkMode = _storage.darkMode,
      _aiSpeed = _storage.aiSpeed;

  final StorageService _storage;
  bool _darkMode;
  AiSpeed _aiSpeed;

  bool get darkMode => _darkMode;
  AiSpeed get aiSpeed => _aiSpeed;

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
}
