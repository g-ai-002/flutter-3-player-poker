import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/action_announcer.dart';
import '../game/ai_player.dart';
import '../game/combo.dart';
import '../game/combo_detector.dart';
import '../game/game_engine.dart';
import '../game/hand_recorder.dart';
import '../game/table_events.dart';
import '../game/turn_driver.dart';
import '../models/hand_record.dart';
import '../models/playing_card.dart';
import '../services/audio_service.dart';
import '../services/hand_history_service.dart';
import '../services/log_service.dart';
import '../services/stats_service.dart';
import 'settings_provider.dart';

/// 对局状态与 AI 调度：把纯逻辑引擎包装成界面可直接消费的 ChangeNotifier。
///
/// 具体职责拆分：
/// - [DdzEngine]：发牌、牌型、轮次与计分等纯规则；
/// - [TurnDriver]：AI 回合的定时调度与异常兜底；
/// - [ActionAnnouncer]：动作事件、音效与日志；
/// - 本类：面向界面的选牌状态、出牌倒计时、人类操作入口与轻提示。
class GameProvider extends ChangeNotifier {
  GameProvider({
    required this.settings,
    DdzEngine? engine,
    AiPlayer? ai,
    TableEventBus? events,
    this.aiDelayOverride,
  }) : engine = engine ?? DdzEngine(),
       ai = ai ?? AiPlayer(),
       events = events ?? TableEventBus() {
    announcer = ActionAnnouncer(
      engine: this.engine,
      events: this.events,
      recorder: recorder,
    );
    driver = TurnDriver(
      engine: this.engine,
      ai: this.ai,
      announcer: announcer,
      level: () => settings.aiLevel,
      speedDelayMs: () => settings.aiSpeed.delayMs,
      delayOverrideMs: aiDelayOverride,
      onChanged: _notify,
      onFeedback: _showFeedback,
      onRedeal: newGame,
    );
  }

  /// 每次出牌回合的思考上限；超时自动不出（领出时自动出最小单张）。
  static const int turnLimitSeconds = 20;

  final SettingsProvider settings;
  final DdzEngine engine;
  final AiPlayer ai;
  final TableEventBus events;

  /// 本局牌谱记录器，新对局开始时重置。
  final HandRecorder recorder = HandRecorder();

  late final ActionAnnouncer announcer;
  late final TurnDriver driver;

  /// 测试时注入固定延迟；为 0 时仍需等待事件队列。
  final int? aiDelayOverride;

  final Set<int> _selectedIds = {};
  final ValueNotifier<int> _turnSeconds = ValueNotifier<int>(0);
  Timer? _feedbackTimer;
  int _clockSerial = -1;
  String? _feedback;
  bool _statsRecorded = false;
  bool _audioReady = false;
  HandRecord? _lastRecord;

  List<PlayingCard> get humanHand => engine.players[0].hand;
  Set<int> get selectedIds => Set.unmodifiable(_selectedIds);
  int? get thinkingPlayer => driver.thinkingPlayer;
  String? get feedback => _feedback;
  GamePhase get phase => engine.phase;
  bool get humanIsLandlord => engine.players[0].isLandlord;
  bool get isHumanTurn => engine.isHumanTurn;
  bool get canPass => engine.isHumanTurn && engine.lastCombo != null;
  GameResult? get result => engine.result;

  /// 当前回合剩余秒数；座位与操作条只监听这个小对象，避免整页每秒重建。
  ValueListenable<int> get turnSecondsLeft => _turnSeconds;

  /// 本局牌谱；对局结束后生成，供结算页查看。
  HandRecord? get lastRecord => _lastRecord;

  /// 人类玩家是地主且尚未明牌时可明牌。
  bool get canReveal =>
      engine.phase == GamePhase.doubling &&
      engine.currentPlayer == 0 &&
      engine.landlord == 0 &&
      !engine.revealed;

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
        if (engine.currentPlayer == 0) return '轮到你叫分';
        return '${engine.players[engine.currentPlayer].name} 正在叫分…';
      case GamePhase.doubling:
        if (engine.currentPlayer == 0) return '是否加倍？';
        return '${engine.players[engine.currentPlayer].name} 正在考虑加倍…';
      case GamePhase.playing:
        if (engine.currentPlayer == 0) {
          return engine.lastCombo == null ? '轮到你出牌 · 自由领出' : '轮到你出牌';
        }
        return '${engine.players[engine.currentPlayer].name} 正在思考…';
    }
  }

  void newGame() {
    _resetTurnState();
    _statsRecorded = false;
    _lastRecord = null;
    engine.start();
    recorder.start(engine);
    if (!_audioReady) {
      _audioReady = true;
      AudioService.instance.prewarm();
    }
    AudioService.instance
      ..startBgm()
      ..play(AudioCue.deal);
    LogService.info(
      '新对局开始，叫分顺序: ${engine.currentPlayer}，AI 难度: '
      '${settings.aiLevel.label}，逻辑更新: ${settings.logicRate.label}',
    );
    events.emit(const TableEvent(type: TableEventType.deal));
    _notify();
    driver.schedule();
  }

  void stop() {
    _resetTurnState();
    if (engine.phase == GamePhase.bidding ||
        engine.phase == GamePhase.doubling ||
        engine.phase == GamePhase.playing) {
      engine.phase = GamePhase.idle;
    }
    AudioService.instance.stopBgm();
    _notify();
  }

  void _resetTurnState() {
    driver.cancel();
    _feedbackTimer?.cancel();
    _feedback = null;
    _selectedIds.clear();
    _clockSerial = -1;
    if (_turnSeconds.value != 0) _turnSeconds.value = 0;
  }

  /// 叫分：0 不叫，1-3 分。
  void bid(int score) {
    if (engine.phase != GamePhase.bidding || engine.currentPlayer != 0) return;
    if (!engine.bid(0, score)) return;
    announcer.bid(0);
    _notify();
    driver.schedule();
  }

  /// 加倍：仅加倍阶段轮到人类玩家时可用。
  void doubleUp(bool doubled) {
    if (engine.phase != GamePhase.doubling || engine.currentPlayer != 0) return;
    if (!engine.doubleUp(0, doubled)) return;
    announcer.doubleUp(0);
    _notify();
    driver.schedule();
  }

  /// 明牌：地主亮出手牌，本局倍数 ×2；不影响当前回合归属。
  void revealHand() {
    if (!canReveal) return;
    if (!engine.revealHand(0)) return;
    announcer.reveal(0);
    _notify();
  }

  void toggleCard(int id) {
    if (!engine.isHumanTurn) return;
    if (!_selectedIds.remove(id)) {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  /// 连续选牌的最终结果：以拖动起点的手牌状态为基准整体替换。
  void setSelection(Iterable<int> ids) {
    if (!engine.isHumanTurn) return;
    final next = ids.toSet();
    if (setEquals(next, _selectedIds)) return;
    _selectedIds
      ..clear()
      ..addAll(next);
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
    announcer.play(0, outcome.combo, text: outcome.text);
    _notify();
    driver.schedule();
  }

  void pass() {
    if (!engine.isHumanTurn) return;
    final error = engine.pass(0);
    if (error != PlayError.none) {
      _showFeedback(error.message);
      return;
    }
    _selectedIds.clear();
    announcer.pass(0);
    _notify();
    driver.schedule();
  }

  void hint() {
    if (!engine.isHumanTurn) return;
    ai.level = settings.aiLevel;
    final cards = ai.hint(engine);
    if (cards == null) {
      _selectedIds.clear();
      _showFeedback('没有能压过上家的牌，建议不出');
      return;
    }
    _selectedIds
      ..clear()
      ..addAll(cards.map((card) => card.id));
    _feedbackTimer?.cancel();
    _feedback = null;
    notifyListeners();
  }

  /// 状态变化的统一出口：同步回合倒计时，终局时写一次生涯统计。
  void _notify() {
    _resetTurnDisplay();
    _recordStats();
    notifyListeners();
  }

  /// 新回合开始时把秒数复位；真正每秒递减由牌桌的 [TurnClock] 驱动，
  /// 这样纯逻辑测试不会残留定时器。
  void _resetTurnDisplay() {
    if (engine.phase != GamePhase.playing) {
      _clockSerial = -1;
      if (_turnSeconds.value != 0) _turnSeconds.value = 0;
      return;
    }
    if (_clockSerial == engine.turnSerial) return;
    _clockSerial = engine.turnSerial;
    _turnSeconds.value = turnLimitSeconds;
  }

  /// 由牌桌计时器每秒调用一次。
  void tickTurn() {
    if (engine.phase != GamePhase.playing) return;
    if (_turnSeconds.value > 0) _turnSeconds.value -= 1;
  }

  /// 计时器挂载时兜底复位，避免外部直接改引擎后秒数为 0。
  void resetTurnSeconds() {
    if (engine.phase == GamePhase.playing) {
      _turnSeconds.value = turnLimitSeconds;
    }
  }

  /// 人类超时：能不出就不出；领出时按规则必须出牌，自动打出最小单张。
  void handleTurnTimeout() {
    if (!engine.isHumanTurn) return;
    _selectedIds.clear();
    if (engine.lastCombo != null) {
      final error = engine.pass(0);
      if (error == PlayError.none) {
        announcer.pass(0);
        _showFeedback('出牌超时，已自动不出');
      }
    } else if (humanHand.isNotEmpty) {
      final outcome = engine.play(0, [humanHand.last]);
      if (outcome.ok) {
        announcer.play(0, outcome.combo, text: outcome.text);
        _showFeedback('出牌超时，已自动出最小单张');
      }
    }
    _notify();
    driver.schedule();
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
    AudioService.instance.play(
      gameResult.humanWon(engine.players[0].isLandlord)
          ? AudioCue.win
          : AudioCue.lose,
    );
    unawaited(
      StatsService.instance.record(
        gameResult,
        humanIsLandlord: engine.players[0].isLandlord,
      ),
    );
    final record = recorder.finish(engine);
    if (record == null) return;
    _lastRecord = record;
    unawaited(HandHistoryService.instance.record(record));
  }

  @override
  void dispose() {
    driver.dispose();
    _feedbackTimer?.cancel();
    _turnSeconds.dispose();
    events.dispose();
    super.dispose();
  }
}
