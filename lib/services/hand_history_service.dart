import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/hand_record.dart';
import '../utils/constants.dart';
import 'log_service.dart';

/// 牌谱服务：内存 + SharedPreferences 双写，仅保留最近若干局。
class HandHistoryService extends ChangeNotifier {
  HandHistoryService._();

  static final HandHistoryService instance = HandHistoryService._();

  static const int maxRecords = 20;

  final List<HandRecord> _records = [];
  SharedPreferences? _prefs;

  List<HandRecord> get records => List.unmodifiable(_records);

  HandRecord? get latest => _records.isEmpty ? null : _records.first;

  @visibleForTesting
  void resetForTest() {
    _records.clear();
    _prefs = null;
  }

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(AppConstants.prefKeyHandHistory);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final loaded = <HandRecord>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          loaded.add(HandRecord.fromJson(item));
        }
      }
      loaded.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      _records
        ..clear()
        ..addAll(loaded.take(maxRecords));
      notifyListeners();
    } catch (e, stack) {
      LogService.error('读取牌谱失败', e, stack);
    }
  }

  Future<void> record(HandRecord record) async {
    _records
      ..removeWhere((item) => item.id == record.id)
      ..insert(0, record);
    if (_records.length > maxRecords) {
      _records.removeRange(maxRecords, _records.length);
    }
    notifyListeners();
    LogService.info(
      '牌谱已保存: ${record.outcomeLabel}, 得分 ${record.humanScore}, '
      '${record.actions.length} 步',
    );
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(
        AppConstants.prefKeyHandHistory,
        jsonEncode([for (final item in _records) item.toJson()]),
      );
    } catch (e, stack) {
      LogService.error('保存牌谱失败', e, stack);
    }
  }

  Future<void> clear() async {
    _records.clear();
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(AppConstants.prefKeyHandHistory);
      LogService.info('已清空牌谱');
    } catch (e, stack) {
      LogService.error('清空牌谱失败', e, stack);
    }
  }
}
