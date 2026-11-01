import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_engine.dart';
import '../utils/constants.dart';
import 'log_service.dart';

/// 生涯数据快照，不可变，便于界面直接展示。
@immutable
class CareerStats {
  const CareerStats({
    this.games = 0,
    this.wins = 0,
    this.totalScore = 0,
    this.landlordGames = 0,
    this.landlordWins = 0,
    this.peasantGames = 0,
    this.peasantWins = 0,
    this.bestStreak = 0,
    this.currentStreak = 0,
  });

  final int games;
  final int wins;
  final int totalScore;
  final int landlordGames;
  final int landlordWins;
  final int peasantGames;
  final int peasantWins;
  final int bestStreak;
  final int currentStreak;

  double get winRate => games == 0 ? 0 : wins / games;

  double get landlordWinRate =>
      landlordGames == 0 ? 0 : landlordWins / landlordGames;

  double get peasantWinRate =>
      peasantGames == 0 ? 0 : peasantWins / peasantGames;

  String get winRateLabel => '${(winRate * 100).toStringAsFixed(1)}%';

  Map<String, dynamic> toJson() => {
    'games': games,
    'wins': wins,
    'totalScore': totalScore,
    'landlordGames': landlordGames,
    'landlordWins': landlordWins,
    'peasantGames': peasantGames,
    'peasantWins': peasantWins,
    'bestStreak': bestStreak,
    'currentStreak': currentStreak,
  };

  factory CareerStats.fromJson(Map<String, dynamic> json) {
    int read(String key) => json[key] is num ? (json[key] as num).toInt() : 0;
    return CareerStats(
      games: read('games'),
      wins: read('wins'),
      totalScore: read('totalScore'),
      landlordGames: read('landlordGames'),
      landlordWins: read('landlordWins'),
      peasantGames: read('peasantGames'),
      peasantWins: read('peasantWins'),
      bestStreak: read('bestStreak'),
      currentStreak: read('currentStreak'),
    );
  }

  CareerStats record({
    required bool humanIsLandlord,
    required GameResult result,
  }) {
    final won = result.humanWon(humanIsLandlord);
    final streak = won ? currentStreak + 1 : 0;
    return CareerStats(
      games: games + 1,
      wins: wins + (won ? 1 : 0),
      totalScore: totalScore + result.scores[0],
      landlordGames: landlordGames + (humanIsLandlord ? 1 : 0),
      landlordWins: landlordWins + (humanIsLandlord && won ? 1 : 0),
      peasantGames: peasantGames + (humanIsLandlord ? 0 : 1),
      peasantWins: peasantWins + (!humanIsLandlord && won ? 1 : 0),
      bestStreak: max(bestStreak, streak),
      currentStreak: streak,
    );
  }
}

/// 生涯统计服务：内存 + SharedPreferences 双写。
class StatsService extends ChangeNotifier {
  StatsService._();

  static final StatsService instance = StatsService._();

  CareerStats _stats = const CareerStats();
  SharedPreferences? _prefs;

  CareerStats get stats => _stats;

  @visibleForTesting
  void resetForTest() {
    _stats = const CareerStats();
    _prefs = null;
  }

  Future<void> load() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final raw = _prefs!.getString(AppConstants.prefKeyStats);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _stats = CareerStats.fromJson(decoded);
      }
    } catch (e, stack) {
      LogService.error('读取生涯统计失败', e, stack);
    }
  }

  Future<void> record(
    GameResult result, {
    required bool humanIsLandlord,
  }) async {
    _stats = _stats.record(humanIsLandlord: humanIsLandlord, result: result);
    notifyListeners();
    LogService.info(
      '对局结束: 地主${result.landlordWon ? '胜' : '负'}, '
      '人类${humanIsLandlord ? '地主' : '农民'}, 得分 ${result.scores[0]}, '
      '倍数 ×${result.multiplier}',
    );
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(
        AppConstants.prefKeyStats,
        jsonEncode(_stats.toJson()),
      );
    } catch (e, stack) {
      LogService.error('保存生涯统计失败', e, stack);
    }
  }

  Future<void> reset() async {
    _stats = const CareerStats();
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(AppConstants.prefKeyStats);
      LogService.info('已清空生涯统计');
    } catch (e, stack) {
      LogService.error('清空生涯统计失败', e, stack);
    }
  }
}
