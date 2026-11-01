import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../utils/constants.dart';

/// 设置持久化。写入失败不影响对局，下次启动回落到默认值。
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  /// 仅供测试使用，配合 SharedPreferences.setMockInitialValues。
  StorageService.test([SharedPreferences? prefs]) : _prefs = prefs;

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    _instance = StorageService._();
    _instance!._prefs = await SharedPreferences.getInstance();
    return _instance!;
  }

  SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) throw StateError('StorageService 尚未初始化');
    return prefs;
  }

  Future<void> _write(
    Future<bool> Function(SharedPreferences prefs) action,
  ) async {
    try {
      await action(_p);
    } catch (_) {}
  }

  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? false;

  Future<void> setDarkMode(bool value) =>
      _write((prefs) => prefs.setBool(AppConstants.prefKeyDarkMode, value));

  AiSpeed get aiSpeed =>
      AiSpeed.fromName(_p.getString(AppConstants.prefKeyAiSpeed));

  Future<void> setAiSpeed(AiSpeed value) => _write(
    (prefs) => prefs.setString(AppConstants.prefKeyAiSpeed, value.name),
  );

  AiLevel get aiLevel =>
      AiLevel.fromName(_p.getString(AppConstants.prefKeyAiLevel));

  Future<void> setAiLevel(AiLevel value) => _write(
    (prefs) => prefs.setString(AppConstants.prefKeyAiLevel, value.name),
  );
}
