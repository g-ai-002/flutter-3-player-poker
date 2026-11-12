import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/action_announcer.dart';
import '../game/ai_player.dart';
import '../game/combo.dart';
import '../game/combo_detector.dart';
import '../game/game_engine.dart';
import '../game/hand_recorder.dart';
import '../game/play_flight.dart';
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
      onPlay: _beginPlayFlight,
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

  final ValueNotifier<Set<int>> _selection = ValueNotifier(const <int>{});
  final ValueNotifier<int> _turnSeconds = ValueNotifier<int>(0);

  /// 正在飞牌的三家：牌堆已排好版但先保持透明，动画落定后一起亮出。
  final Set<int> _flyingPlays = {};
  final Map<int, Timer> _flightTimers = {};
  Timer? _feedbackTimer;
  int _clockSerial = -1;
  String? _feedback;
  bool _statsRecorded = false;
  bool _audioReady = false;
  HandRecord? _lastRecord;

  List<PlayingCard> get humanHand => engine.players[0].hand;

  /// 选牌状态：手牌、操作条与提示层只订阅这个小对象。
  ///
  /// 点选一张牌只刷新这三处，不再通知整张牌桌页重建。
  ValueListenable<Set<int>> get selection => _selection;

  Set<int> get selectedIds => _selection.value;
  int? get thinkingPlayer => driver.thinkingPlayer;
  String? get feedback => _feedback;
  GamePhase get phase => engine.phase;
  bool get humanIsLandlord => engine.players[0].isLandlord;
  bool get isHumanTurn => engine.isHumanTurn;
  bool get canPass => engine.isHumanTurn && engine.lastCombo != null;
  GameResult? get result => engine.result;

  /// 当前回合剩余秒数；座位与操作条只监听这个小对象，避免整页每秒重建。
  ValueListenable<int> get turnSecondsLeft => _turnSeconds;

  /// 该家是否正在飞牌：为 true 时出牌区先保持透明，等飞牌落定再亮出。
  bool isPlayFlying(int playerId) => _flyingPlays.contains(playerId);

  /// 本局牌谱；对局结束后生成，供结算页查看。
  HandRecord? get lastRecord => _lastRecord;

  /// 人类玩家是地主且尚未明牌时可明牌。
  bool get canReveal =>
      engine.phase == GamePhase.doubling &&
      engine.currentPlayer == 0 &&
      engine.landlord == 0 &&
      !engine.revealed;

  List<PlayingCard> get selectedCards =>
      humanHand.where((card) => _selection.value.contains(card.id)).toList();

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
    shutdown();
    _notify();
  }

  /// 页面关闭时的静默收尾：取消 AI 与提示定时器、停止背景音乐，不通知界面。
  ///
  /// 与 [stop] 的区别是不触发 `notifyListeners`，可以在 Widget 的 dispose 里安全调用，
  /// 保证退出牌桌后不残留任何后台任务。
  void shutdown() {
    driver.cancel();
    _feedbackTimer?.cancel();
    _feedback = null;
    _setSelection(const {});
    _clearFlights();
    _clockSerial = -1;
    if (engine.phase == GamePhase.bidding ||
        engine.phase == GamePhase.doubling ||
        engine.phase == GamePhase.playing) {
      engine.phase = GamePhase.idle;
    }
    AudioService.instance.stopBgm();
  }

  void _resetTurnState() {
    driver.cancel();
    _feedbackTimer?.cancel();
    _feedback = null;
    _setSelection(const {});
    _clearFlights();
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
    final next = Set<int>.of(_selection.value);
    if (!next.remove(id)) next.add(id);
    // 选牌只更新小对象，手牌、操作条与提示层各自局部刷新。
    _setSelection(next);
  }

  /// 连续选牌的最终结果：以拖动起点的手牌状态为基准整体替换。
  void setSelection(Iterable<int> ids) {
    if (!engine.isHumanTurn) return;
    final next = ids.toSet();
    if (setEquals(next, _selection.value)) return;
    _setSelection(next);
  }

  /// 选牌快照不可变，订阅者拿到的集合不会被后续操作悄悄改掉。
  void _setSelection(Iterable<int> ids) {
    final next = Set.unmodifiable(ids);
    if (setEquals(next, _selection.value)) return;
    _selection.value = next;
  }

  void playSelected() {
    if (!engine.isHumanTurn) return;
    final cards = selectedCards;
    final outcome = engine.play(0, cards);
    if (!outcome.ok) {
      _showFeedback(outcome.error.message);
      return;
    }
    _setSelection(const {});
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
    _setSelection(const {});
    announcer.pass(0);
    _notify();
    driver.schedule();
  }

  /// 叫分建议：轮到自己叫分时给出牌力评分与推荐分档。
  String? get bidAdvice {
    if (engine.phase != GamePhase.bidding || engine.currentPlayer != 0) {
      return null;
    }
    final strength = ai.strengthOf(humanHand);
    final score = ai.advisedBid(humanHand, engine.highestBid);
    final action = score == 0 ? '建议不叫' : '建议叫 $score 分';
    return '牌力 ${strength.toStringAsFixed(1)} · $action';
  }

  /// 残局提醒：对手只剩 1~2 张牌时给一句战术提示，队友不计入。
  String? get endgameAlert {
    if (engine.phase != GamePhase.playing) return null;
    final humanIsLandlord = engine.players[0].isLandlord;
    for (final player in engine.players.skip(1)) {
      if (player.isLandlord == humanIsLandlord || player.hand.isEmpty) {
        continue;
      }
      if (player.hand.length == 1) return '${player.name}只剩 1 张 · 出大牌压制';
      if (player.hand.length == 2) return '${player.name}只剩 2 张 · 小心一手走完';
    }
    return null;
  }

  void hint() {
    if (!engine.isHumanTurn) return;
    ai.level = settings.aiLevel;
    final advice = ai.hintAdvice(engine);
    final cards = advice.cards;
    if (cards == null) {
      _setSelection(const {});
      _showFeedback(advice.reason);
      return;
    }
    _setSelection(cards.map((card) => card.id));
    // 提示理由直接走反馈通道，选牌由上面的小对象通知，牌桌不需要整页重建。
    _showFeedback(advice.reason, duration: const Duration(seconds: 4));
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
    _setSelection(const {});
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

  void _showFeedback(
    String message, {
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    _feedbackTimer?.cancel();
    _feedback = message;
    notifyListeners();
    _feedbackTimer = Timer(duration, () {
      _feedback = null;
      notifyListeners();
    });
  }

  /// 出牌后先收起牌堆，等飞牌动画落定再亮出，避免牌先于动画出现在桌上。
  ///
  /// 时长与牌桌层的飞行节拍共用 [PlayFlight]，牌多牌少都能对齐。
  void _beginPlayFlight(int playerId, int cardCount) {
    _flightTimers.remove(playerId)?.cancel();
    _flyingPlays.add(playerId);
    _flightTimers[playerId] = Timer(PlayFlight.revealDelay(cardCount), () {
      _flightTimers.remove(playerId);
      if (_flyingPlays.remove(playerId)) notifyListeners();
    });
  }

  void _clearFlights() {
    for (final timer in _flightTimers.values) {
      timer.cancel();
    }
    _flightTimers.clear();
    _flyingPlays.clear();
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
    _clearFlights();
    _selection.dispose();
    _turnSeconds.dispose();
    events.dispose();
    super.dispose();
  }
}
