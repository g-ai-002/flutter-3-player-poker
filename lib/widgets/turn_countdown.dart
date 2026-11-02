import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

/// 牌桌计时器：每个出牌回合重置 20 秒，归零时由对局状态处理超时。
///
/// 计时器挂在牌桌 Widget 上而不是 Provider 上，页面销毁时自动取消，
/// 纯逻辑测试也不会留下悬挂的周期性定时器。
class TurnClock extends StatefulWidget {
  const TurnClock({
    super.key,
    required this.provider,
    required this.serial,
    required this.active,
  });

  final GameProvider provider;
  final int serial;
  final bool active;

  @override
  State<TurnClock> createState() => _TurnClockState();
}

class _TurnClockState extends State<TurnClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(TurnClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serial != widget.serial ||
        oldWidget.active != widget.active) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (!widget.active || widget.provider.phase != GamePhase.playing) return;
    if (widget.provider.turnSecondsLeft.value == 0) {
      widget.provider.resetTurnSeconds();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final provider = widget.provider;
      if (provider.phase != GamePhase.playing) {
        timer.cancel();
        return;
      }
      if (provider.turnSecondsLeft.value <= 1) {
        provider.tickTurn();
        timer.cancel();
        _timer = null;
        provider.handleTurnTimeout();
      } else {
        provider.tickTurn();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 回合倒计时徽标：只监听秒数本身，避免牌桌每秒重建。
class TurnCountdown extends StatelessWidget {
  const TurnCountdown({super.key, required this.seconds, this.compact = false});

  final ValueListenable<int> seconds;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: seconds,
      builder: (context, value, _) {
        final urgent = value <= 5;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 8,
            vertical: compact ? 1 : 3,
          ),
          decoration: BoxDecoration(
            color: urgent
                ? const Color(0xFF8E3325).withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: urgent
                  ? const Color(0xFFE08A7A)
                  : kGold.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: compact ? 10 : 13,
                color: urgent ? Colors.white : kGoldSoft,
              ),
              const SizedBox(width: 3),
              Text(
                '${value}s',
                style: TextStyle(
                  color: urgent ? Colors.white : kGoldSoft,
                  fontSize: compact ? 9 : 11,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
