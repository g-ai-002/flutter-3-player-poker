import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_settings.dart';
import '../services/log_service.dart';
import 'action_announcer.dart';
import 'ai_player.dart';
import 'game_engine.dart';

/// 回合驱动：负责 AI 叫分 / 加倍 / 出牌的节拍与兜底。
///
/// 人类回合不占用定时器；AI 的决策一旦被引擎拒绝，就降级重试
/// （叫分 → 不叫，加倍 → 不加倍，出牌 → 不出或出最小单张），
/// 保证异常情况下对局仍能继续推进，不会卡在某个 AI 回合。
class TurnDriver {
  TurnDriver({
    required this.engine,
    required this.ai,
    required this.announcer,
    required this.level,
    required this.speedDelayMs,
    required this.onChanged,
    required this.onFeedback,
    required this.onRedeal,
    this.delayOverrideMs,
  });

  final DdzEngine engine;
  final AiPlayer ai;
  final ActionAnnouncer announcer;

  /// 取当前设置中的 AI 难度；每次调度都重新读取，设置改动即时生效。
  final AiLevel Function() level;

  /// 取当前设置中的 AI 思考延迟。
  final int Function() speedDelayMs;

  final VoidCallback onChanged;
  final void Function(String message) onFeedback;
  final VoidCallback onRedeal;

  /// 测试时注入固定延迟；为 0 时仍需等待事件队列。
  final int? delayOverrideMs;

  Timer? _timer;
  int? _thinkingPlayer;

  int? get thinkingPlayer => _thinkingPlayer;

  /// 依据当前阶段安排下一步：人类回合立即交还控制权，AI 回合延时决策。
  void schedule() {
    _timer?.cancel();
    ai.level = level();
    switch (engine.phase) {
      case GamePhase.redeal:
        _thinkingPlayer = null;
        onChanged();
        _showRedealFeedback();
        _timer = Timer(const Duration(milliseconds: 1500), onRedeal);
        return;
      case GamePhase.finished:
      case GamePhase.idle:
        _thinkingPlayer = null;
        onChanged();
        return;
      case GamePhase.bidding:
      case GamePhase.doubling:
      case GamePhase.playing:
        if (engine.currentPlayer == 0) {
          _thinkingPlayer = null;
          onChanged();
          return;
        }
    }

    _thinkingPlayer = engine.currentPlayer;
    onChanged();
    final delay = Duration(milliseconds: delayOverrideMs ?? speedDelayMs());
    _timer = Timer(delay, () {
      switch (engine.phase) {
        case GamePhase.bidding:
          _aiBid();
        case GamePhase.doubling:
          _aiDouble();
        case GamePhase.playing:
          _aiPlay();
        default:
          break;
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _thinkingPlayer = null;
  }

  void dispose() => cancel();

  void _aiBid() {
    if (engine.phase != GamePhase.bidding) return;
    final actor = engine.currentPlayer;
    final score = ai.bidScore(engine);
    if (!engine.bid(actor, score)) {
      LogService.warning('AI 叫分 $score 被拒绝，降级为不叫');
      if (!engine.bid(actor, 0)) {
        _fail('AI 叫分异常，请重新开始本局');
        return;
      }
    }
    _thinkingPlayer = null;
    announcer.bid(actor);
    schedule();
  }

  void _aiDouble() {
    if (engine.phase != GamePhase.doubling) return;
    final actor = engine.currentPlayer;
    if (ai.shouldReveal(engine) && engine.revealHand(actor)) {
      announcer.reveal(actor);
    }
    final doubled = ai.shouldDouble(engine);
    if (!engine.doubleUp(actor, doubled)) {
      LogService.warning('AI ${doubled ? '加倍' : '不加倍'}被拒绝，降级为不加倍');
      if (!engine.doubleUp(actor, false)) {
        _fail('AI 加倍异常，请重新开始本局');
        return;
      }
    }
    _thinkingPlayer = null;
    announcer.doubleUp(actor);
    schedule();
  }

  void _aiPlay() {
    if (engine.phase != GamePhase.playing) return;
    final actor = engine.currentPlayer;
    final cards = ai.choose(engine);
    _thinkingPlayer = null;
    var advanced = false;
    if (cards == null) {
      if (engine.lastCombo == null) {
        advanced = _leadFallback(actor, 'AI 未给出领出牌');
      } else {
        advanced = _passMove(actor);
      }
    } else {
      final outcome = engine.play(actor, cards);
      if (outcome.ok) {
        announcer.play(actor, outcome.combo, text: outcome.text);
        advanced = true;
      } else {
        LogService.error(
          'AI 出牌被拒绝: ${outcome.error.message} '
          '[${cards.map((card) => card.displayName).join(' ')}]',
        );
        advanced = engine.lastCombo != null
            ? _passMove(actor)
            : _leadFallback(actor, 'AI 领出被拒绝');
      }
    }
    if (advanced) {
      schedule();
    } else {
      onChanged();
      onFeedback('AI 出牌异常，请重新开始本局');
    }
  }

  bool _passMove(int actor) {
    final error = engine.pass(actor);
    if (error != PlayError.none) {
      LogService.error('AI 不出被拒绝: ${error.message}');
      return false;
    }
    announcer.pass(actor);
    return true;
  }

  /// 领出兜底：出最小的一张单牌，保证对局不会卡死。
  bool _leadFallback(int actor, String reason) {
    final hand = engine.players[actor].hand;
    if (hand.isEmpty) {
      LogService.error('$reason，且手牌为空');
      return false;
    }
    final card = hand.last;
    final outcome = engine.play(actor, [card]);
    if (!outcome.ok) {
      LogService.error('$reason，兜底出牌失败: ${outcome.error.message}');
      return false;
    }
    LogService.warning('$reason，兜底出最小单张 ${card.displayName}');
    announcer.play(actor, outcome.combo, text: outcome.text);
    return true;
  }

  void _showRedealFeedback() {
    final text = engine.lastActionText;
    onFeedback(text == null || text.isEmpty ? '三家都不叫，重新发牌' : text);
  }

  /// 引擎连续拒绝兜底动作：停止自动推进并提示用户重开，避免无限重试。
  void _fail(String message) {
    LogService.error(message);
    _thinkingPlayer = null;
    onChanged();
    onFeedback(message);
  }
}
