import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/ai_player.dart';
import '../game/combo.dart';
import '../game/combo_detector.dart';
import '../game/game_engine.dart';
import '../game/table_events.dart';
import '../models/playing_card.dart';
import '../services/log_service.dart';
import '../services/stats_service.dart';
import 'settings_provider.dart';

/// 对局状态与 AI 调度：把纯逻辑引擎包装成界面可直接消费的 ChangeNotifier。
class GameProvider extends ChangeNotifier {
  GameProvider({
    required this.settings,
    DdzEngine? engine,
    AiPlayer? ai,
    TableEventBus? events,
    this.aiDelayOverride,
  }) : engine = engine ?? DdzEngine(),
       ai = ai ?? AiPlayer(),
       events = events ?? TableEventBus();

  final SettingsProvider settings;
  final DdzEngine engine;
  final AiPlayer ai;
  final TableEventBus events;

  /// 测试时注入固定延迟；为 0 时仍需等待事件队列。
  final int? aiDelayOverride;

  final Set<int> _selectedIds = {};
  Timer? _timer;
  Timer? _feedbackTimer;
  int? _thinkingPlayer;
  String? _feedback;
  bool _statsRecorded = false;

  List<PlayingCard> get humanHand => engine.players[0].hand;
  Set<int> get selectedIds => Set.unmodifiable(_selectedIds);
  int? get thinkingPlayer => _thinkingPlayer;
  String? get feedback => _feedback;
  GamePhase get phase => engine.phase;
  bool get humanIsLandlord => engine.players[0].isLandlord;
  bool get isHumanTurn => engine.isHumanTurn;
  bool get canPass => engine.isHumanTurn && engine.lastCombo != null;
  bool get isWaitingForAi => _thinkingPlayer != null;
  GameResult? get result => engine.result;

  List<PlayingCard> get selectedCards =>
      humanHand.where((card) => _selectedIds.contains(card.id)).toList();

  Combo? get selectedCombo => detectCombo(selectedCards);

  bool get canPlay {
    if (!engine.isHumanTurn) return false;
    final combo = selectedCombo;
    if (combo == null) return false;
    return engine.lastCombo == null || beatsCombo(combo, engine.lastCombo);
  }

  String get turnHint {
    switch (engine.phase) {
      case GamePhase.idle:
        return '点击开始对局';
      case GamePhase.redeal:
        return '重新发牌中…';
      case GamePhase.finished:
        final res = engine.result;
        if (res == null) return '对局结束';
        return res.landlordWon ? '地主获胜' : '农民获胜';
      case GamePhase.bidding:
        if (engine.currentPlayer == 0) return '轮到你叫地主';
        return '${engine.players[engine.currentPlayer].name} 正在叫牌…';
      case GamePhase.playing:
        if (engine.currentPlayer == 0) {
          return engine.lastCombo == null ? '轮到你出牌 · 自由领出' : '轮到你出牌';
        }
        return '${engine.players[engine.currentPlayer].name} 正在思考…';
    }
  }

  void newGame() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
    _feedback = null;
    _selectedIds.clear();
    _thinkingPlayer = null;
    _statsRecorded = false;
    engine.start();
    LogService.info('新对局开始，叫地主顺序: ${engine.currentPlayer}');
    events.emit(const TableEvent(type: TableEventType.deal));
    notifyListeners();
    _schedule();
  }

  void stop() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
    _thinkingPlayer = null;
    if (engine.phase == GamePhase.bidding ||
        engine.phase == GamePhase.playing) {
      engine.phase = GamePhase.idle;
    }
    _selectedIds.clear();
    notifyListeners();
  }

  void bid(bool call) {
    if (engine.phase != GamePhase.bidding || engine.currentPlayer != 0) return;
    engine.bid(0, call);
    events.emit(
      TableEvent(
        type: TableEventType.bid,
        player: 0,
        text: call ? '叫地主' : '不叫',
      ),
    );
    LogService.info('玩家${call ? '叫地主' : '不叫'}');
    notifyListeners();
    _schedule();
  }

  void toggleCard(int id) {
    if (!engine.isHumanTurn) return;
    if (!_selectedIds.remove(id)) {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isEmpty) return;
    _selectedIds.clear();
    notifyListeners();
  }

  void playSelected() {
    if (!engine.isHumanTurn) return;
    final cards = selectedCards;
    final outcome = engine.play(0, cards);
    if (!outcome.ok) {
      _showFeedback(outcome.error.message);
      return;
    }
    _selectedIds.clear();
    _emitPlay(0, outcome.combo);
    notifyListeners();
    _schedule();
  }

  void pass() {
    if (!engine.isHumanTurn) return;
    final error = engine.pass(0);
    if (error != PlayError.none) {
      _showFeedback(error.message);
      return;
    }
    _selectedIds.clear();
    events.emit(const TableEvent(type: TableEventType.pass, player: 0));
    LogService.info('玩家不出');
    notifyListeners();
    _schedule();
  }

  void hint() {
    if (!engine.isHumanTurn) return;
    final cards = ai.hint(engine);
    if (cards == null) {
      _showFeedback('没有能压过上家的牌，建议不出');
      return;
    }
    _selectedIds
      ..clear()
      ..addAll(cards.map((card) => card.id));
    _feedback = null;
    notifyListeners();
  }

  void _schedule() {
    _timer?.cancel();
    switch (engine.phase) {
      case GamePhase.redeal:
        _thinkingPlayer = null;
        _showFeedback('三家都不叫，重新发牌');
        _timer = Timer(const Duration(milliseconds: 1500), newGame);
        return;
      case GamePhase.finished:
        _thinkingPlayer = null;
        _recordStats();
        notifyListeners();
        return;
      case GamePhase.idle:
        return;
      case GamePhase.bidding:
      case GamePhase.playing:
        if (engine.currentPlayer == 0) {
          _thinkingPlayer = null;
          notifyListeners();
          return;
        }
    }

    _thinkingPlayer = engine.currentPlayer;
    notifyListeners();
    final delay = Duration(
      milliseconds: aiDelayOverride ?? settings.aiSpeed.delayMs,
    );
    _timer = Timer(delay, () {
      if (engine.phase == GamePhase.bidding) {
        _aiBid();
      } else if (engine.phase == GamePhase.playing) {
        _aiPlay();
      }
    });
  }

  void _aiBid() {
    if (engine.phase != GamePhase.bidding) return;
    final actor = engine.currentPlayer;
    final call = ai.shouldCall(engine.players[actor].hand);
    engine.bid(actor, call);
    _thinkingPlayer = null;
    events.emit(
      TableEvent(
        type: TableEventType.bid,
        player: actor,
        text: call ? '叫地主' : '不叫',
      ),
    );
    LogService.info('AI ${engine.players[actor].name} ${call ? '叫地主' : '不叫'}');
    notifyListeners();
    _schedule();
  }

  void _aiPlay() {
    if (engine.phase != GamePhase.playing) return;
    final actor = engine.currentPlayer;
    final cards = ai.choose(engine);
    _thinkingPlayer = null;
    if (cards == null) {
      if (engine.lastCombo == null) {
        // 兜底：领出时不能不出，出最小的一张保证对局继续。
        final fallback = [engine.players[actor].hand.last];
        final outcome = engine.play(actor, fallback);
        if (outcome.ok) _emitPlay(actor, outcome.combo);
      } else {
        final error = engine.pass(actor);
        if (error == PlayError.none) {
          events.emit(TableEvent(type: TableEventType.pass, player: actor));
          LogService.info('AI ${engine.players[actor].name} 不出');
        }
      }
    } else {
      final outcome = engine.play(actor, cards);
      if (outcome.ok) {
        _emitPlay(actor, outcome.combo);
      } else {
        LogService.error('AI 出牌被拒绝: ${outcome.error.message}');
        if (engine.lastCombo != null) {
          engine.pass(actor);
          events.emit(TableEvent(type: TableEventType.pass, player: actor));
        }
      }
    }
    notifyListeners();
    _schedule();
  }

  void _emitPlay(int player, Combo? combo) {
    if (combo == null) return;
    events.emit(
      TableEvent(type: TableEventType.play, player: player, cards: combo.cards),
    );
    if (combo.isBomb) {
      events.emit(
        TableEvent(
          type: TableEventType.blast,
          player: player,
          text: combo.description,
        ),
      );
    }
    LogService.info(
      '${engine.players[player].name} 出牌: ${combo.description} '
      '[${combo.cards.map((c) => c.displayName).join(' ')}], '
      '剩余 ${engine.players[player].hand.length} 张',
    );
  }

  void _showFeedback(String message) {
    _feedbackTimer?.cancel();
    _feedback = message;
    notifyListeners();
    _feedbackTimer = Timer(const Duration(milliseconds: 2200), () {
      _feedback = null;
      notifyListeners();
    });
  }

  void _recordStats() {
    final gameResult = engine.result;
    if (gameResult == null || _statsRecorded) return;
    _statsRecorded = true;
    unawaited(
      StatsService.instance.record(
        gameResult,
        humanIsLandlord: engine.players[0].isLandlord,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _feedbackTimer?.cancel();
    events.dispose();
    super.dispose();
  }
}
