import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart';

import '../models/playing_card.dart';
import 'table_events.dart';

/// Flame 牌桌：绒面背景、浮尘、发牌/出牌飞行动画与炸弹冲击波。
///
/// 交互全部由 Flutter 组件承担，这里只负责视觉层，避免两套手势系统冲突。
class DdzTableGame extends FlameGame {
  DdzTableGame({required this.bus, this.introDeal = false});

  final TableEventBus bus;

  /// 进入牌桌时补一次发牌动画：首局的发牌事件在牌桌订阅之前就已发出。
  final bool introDeal;
  late final DustLayer _dust;

  @override
  Color backgroundColor() => const Color(0xFF081A11);

  @override
  Future<void> onLoad() async {
    add(FeltBackground());
    _dust = DustLayer();
    add(_dust);
    bus.subscribe(_onEvent);
    if (introDeal) _playDeal();
  }

  @override
  void onRemove() {
    bus.unsubscribe(_onEvent);
    super.onRemove();
  }

  Offset seatPoint(int player) {
    return switch (player) {
      1 => Offset(size.x * 0.86, size.y * 0.26),
      2 => Offset(size.x * 0.14, size.y * 0.26),
      _ => Offset(size.x * 0.5, size.y * 0.84),
    };
  }

  Offset pilePoint(int player) {
    return switch (player) {
      1 => Offset(size.x * 0.66, size.y * 0.47),
      2 => Offset(size.x * 0.34, size.y * 0.47),
      _ => Offset(size.x * 0.5, size.y * 0.66),
    };
  }

  void _onEvent(TableEvent event) {
    switch (event.type) {
      case TableEventType.deal:
        _playDeal();
      case TableEventType.play:
        final cards = event.cards.take(8).toList();
        for (var i = 0; i < cards.length; i++) {
          add(
            CardFlight(
              card: cards[i],
              from: seatPoint(event.player),
              to: pilePoint(event.player) + Offset(i * 10, -i * 2),
              delay: i * 0.035,
              duration: 0.32,
            ),
          );
        }
      case TableEventType.blast:
        final point = pilePoint(event.player);
        add(BlastWave(position: point));
        add(
          BlastWave(
            position: point,
            delay: 0.12,
            color: const Color(0xFFD8B56A),
          ),
        );
      case TableEventType.pass:
      case TableEventType.bid:
        break;
    }
  }

  void _playDeal() {
    for (var player = 0; player < 3; player++) {
      for (var i = 0; i < 5; i++) {
        add(
          CardFlight(
            card: null,
            from: Offset(size.x * 0.5, size.y * 0.45),
            to: seatPoint(player),
            delay: 0.04 * (i * 3 + player),
            duration: 0.36,
          ),
        );
      }
    }
  }
}

class FeltBackground extends Component with HasGameReference<DdzTableGame> {
  static final TextPaint _watermark = TextPaint(
    style: const TextStyle(
      fontSize: 240,
      fontWeight: FontWeight.w900,
      color: Color(0x0DFFFFFF),
    ),
  );

  @override
  void render(Canvas canvas) {
    final size = game.size;
    final rect = Offset.zero & Size(size.x, size.y);
    final felt = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.15),
        radius: 0.95,
        colors: [Color(0xFF1B6B46), Color(0xFF0F4229), Color(0xFF071A11)],
        stops: [0, 0.58, 1],
      ).createShader(rect);
    canvas.drawRect(rect, felt);

    final oval = Rect.fromCenter(
      center: Offset(size.x * 0.5, size.y * 0.48),
      width: size.x * 0.93,
      height: size.y * 0.92,
    );
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFD8B56A).withValues(alpha: 0.22),
    );
    canvas.drawOval(
      oval.deflate(10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFFD8B56A).withValues(alpha: 0.12),
    );

    _watermark.render(
      canvas,
      '斗',
      Vector2(size.x * 0.5, size.y * 0.47),
      anchor: Anchor.center,
    );
  }
}

class DustLayer extends Component with HasGameReference<DdzTableGame> {
  DustLayer() : _random = math.Random(7);

  final math.Random _random;
  final List<_Dust> _particles = [];
  bool _seeded = false;

  @override
  void update(double dt) {
    if (!_seeded) {
      _seeded = true;
      for (var i = 0; i < 22; i++) {
        _particles.add(
          _Dust(
            x: _random.nextDouble(),
            y: _random.nextDouble(),
            speed: 0.01 + _random.nextDouble() * 0.025,
            radius: 0.6 + _random.nextDouble() * 1.6,
            phase: _random.nextDouble() * math.pi * 2,
          ),
        );
      }
    }
    for (final particle in _particles) {
      particle
        ..y -= particle.speed * dt
        ..phase += dt * 0.5;
      if (particle.y < -0.02) particle.y = 1.02;
    }
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    for (final particle in _particles) {
      final x = (particle.x + math.sin(particle.phase) * 0.015) * size.x;
      final paint = Paint()
        ..color = const Color(0xFFEBD6A4).withValues(alpha: 0.10);
      canvas.drawCircle(Offset(x, particle.y * size.y), particle.radius, paint);
    }
  }
}

class _Dust {
  _Dust({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.phase,
  });

  final double x;
  double y;
  final double speed;
  final double radius;
  double phase;
}

class CardFlight extends Component {
  CardFlight({
    required this.card,
    required this.from,
    required this.to,
    this.delay = 0,
    this.duration = 0.34,
  });

  final PlayingCard? card;
  final Offset from;
  final Offset to;
  double delay;
  final double duration;
  double _elapsed = 0;

  static const double _cardWidth = 34;
  static const double _cardHeight = 48;
  static final TextPaint _blackRank = TextPaint(
    style: const TextStyle(
      fontSize: 13,
      height: 1,
      fontWeight: FontWeight.w800,
      color: Color(0xFF1F2A24),
    ),
  );
  static final TextPaint _redRank = TextPaint(
    style: const TextStyle(
      fontSize: 13,
      height: 1,
      fontWeight: FontWeight.w800,
      color: Color(0xFFC0392B),
    ),
  );
  static final TextPaint _suit = TextPaint(
    style: const TextStyle(fontSize: 15, height: 1, color: Color(0xFF1F2A24)),
  );

  @override
  void update(double dt) {
    if (delay > 0) {
      delay -= dt;
      return;
    }
    _elapsed += dt;
    if (_elapsed >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (delay > 0) return;
    final t = Curves.easeOutCubic.transform(
      (_elapsed / duration).clamp(0.0, 1.0),
    );
    final position = Offset.lerp(from, to, t)!;
    final arc = math.sin(t * math.pi) * 18;
    final rect = Rect.fromCenter(
      center: Offset(position.dx, position.dy - arc),
      width: _cardWidth,
      height: _cardHeight,
    );
    final radius = RRect.fromRectAndRadius(rect, const Radius.circular(5));

    if (card == null) {
      canvas.drawRRect(
        radius,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF1B5C3C), Color(0xFF0C2B1C)],
          ).createShader(rect),
      );
      canvas.drawRRect(
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFD8B56A).withValues(alpha: 0.6),
      );
      return;
    }

    final face = card!;
    canvas.drawRRect(radius, Paint()..color = const Color(0xFFFFFBF0));
    canvas.drawRRect(
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0xFFD8CEB6),
    );
    final paint = face.isRed ? _redRank : _blackRank;
    final origin = Vector2(rect.left + 3, rect.top + 2);
    paint.render(canvas, face.rankLabel, origin);
    if (face.isJoker) {
      _suit.render(
        canvas,
        face.rank == 17 ? '大' : '小',
        Vector2(rect.left + 3, rect.top + 18),
      );
    } else {
      _suit.render(
        canvas,
        face.suitSymbol,
        Vector2(rect.center.dx, rect.center.dy + 3),
        anchor: Anchor.center,
      );
    }
  }
}

class BlastWave extends Component {
  BlastWave({
    required this.position,
    this.delay = 0,
    this.color = const Color(0xFFE07A4F),
  });

  final Offset position;
  double delay;
  final Color color;
  double _elapsed = 0;
  static const double _duration = 0.55;

  @override
  void update(double dt) {
    if (delay > 0) {
      delay -= dt;
      return;
    }
    _elapsed += dt;
    if (_elapsed >= _duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    if (delay > 0) return;
    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    final radius = 30 + t * 180;
    final alpha = (1 - t) * 0.55;
    canvas.drawCircle(
      position,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - t) + 1
        ..color = color.withValues(alpha: alpha),
    );
    canvas.drawCircle(
      position,
      radius * 0.65,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFEBD6A4).withValues(alpha: alpha * 0.8),
    );
  }
}
