import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/playing_card.dart';
import 'logic_clock.dart';
import 'table_events.dart';

/// Flame 牌桌：绒面背景、浮尘、发牌/出牌飞行动画与炸弹冲击波。
///
/// 交互全部由 Flutter 组件承担，这里只负责视觉层，避免两套手势系统冲突。
class DdzTableGame extends FlameGame {
  DdzTableGame({
    required this.bus,
    this.introDeal = false,
    int logicHz = LogicClock.defaultRate,
  }) : _clock = LogicClock(rate: logicHz);

  final TableEventBus bus;

  /// 进入牌桌时补一次发牌动画：首局的发牌事件在牌桌订阅之前就已发出。
  final bool introDeal;

  final LogicClock _clock;

  @override
  Color backgroundColor() => const Color(0xFF081A11);

  /// 渲染仍按屏幕刷新率进行，组件逻辑按设置的固定步长推进。
  @override
  void update(double dt) {
    final steps = _clock.advance(dt);
    for (var i = 0; i < steps; i++) {
      super.update(_clock.step);
    }
  }

  @override
  Future<void> onLoad() async {
    add(FeltBackground());
    // 浮尘只保留在移动/桌面端，Web 端优先保证动画流畅度。
    if (!kIsWeb) add(DustLayer());
    bus.subscribe(_onEvent);
    if (introDeal) _playDeal();
  }

  bool _detached = false;

  /// 牌桌页销毁时回收：退订事件总线后再交给 Flame 停止游戏循环。
  ///
  /// 页面关闭后对局仍可能发出事件，退订后不会再有组件被添加到一个不再渲染的场景里。
  @override
  void detach() {
    if (!_detached) {
      _detached = true;
      bus.unsubscribe(_onEvent);
    }
    super.detach();
  }

  /// 三家出牌区的相对坐标，由 Flutter 布局回传；未回传前使用经验位置。
  final Map<int, Offset> _pileAnchors = {};

  void setPileAnchors(Map<int, Offset> anchors) {
    _pileAnchors
      ..clear()
      ..addAll(anchors);
  }

  Offset seatPoint(int player) {
    return switch (player) {
      1 => Offset(size.x * 0.86, size.y * 0.26),
      2 => Offset(size.x * 0.14, size.y * 0.26),
      _ => Offset(size.x * 0.5, size.y * 0.84),
    };
  }

  /// 飞牌落点：优先使用布局回传的真实出牌区中心。
  Offset pilePoint(int player) {
    final anchor = _pileAnchors[player];
    if (anchor != null) {
      return Offset(anchor.dx * size.x, anchor.dy * size.y);
    }
    return switch (player) {
      1 => Offset(size.x * 0.82, size.y * 0.34),
      2 => Offset(size.x * 0.18, size.y * 0.34),
      _ => Offset(size.x * 0.5, size.y * 0.74),
    };
  }

  void _onEvent(TableEvent event) {
    switch (event.type) {
      case TableEventType.deal:
        _playDeal();
      case TableEventType.play:
        final cards = event.cards.take(kIsWeb ? 6 : 8).toList();
        final target = pilePoint(event.player) - const Offset(0, 6);
        for (var i = 0; i < cards.length; i++) {
          add(
            CardFlight(
              card: cards[i],
              from: seatPoint(event.player),
              to: target + Offset(i * 10, -i * 2),
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
      case TableEventType.double:
      case TableEventType.reveal:
        break;
    }
  }

  void _playDeal() {
    const perPlayer = kIsWeb ? 3 : 5;
    for (var player = 0; player < 3; player++) {
      for (var i = 0; i < perPlayer; i++) {
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

  Vector2? _cachedSize;
  ui.Picture? _picture;

  /// 绒面、金边与水印合成为一张图片缓存，每帧只做一次 drawPicture。
  void _rebuild(Vector2 size) {
    final rect = Offset.zero & Size(size.x, size.y);
    final felt = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.15),
        radius: 0.95,
        colors: [Color(0xFF1B6B46), Color(0xFF0F4229), Color(0xFF071A11)],
        stops: [0, 0.58, 1],
      ).createShader(rect);
    final oval = Rect.fromCenter(
      center: Offset(size.x * 0.5, size.y * 0.48),
      width: size.x * 0.93,
      height: size.y * 0.92,
    );
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFD8B56A).withValues(alpha: 0.22);
    final rimInner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = const Color(0xFFD8B56A).withValues(alpha: 0.12);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(rect, felt);
    canvas.drawOval(oval, rim);
    canvas.drawOval(oval.deflate(10), rimInner);
    _watermark.render(
      canvas,
      '斗',
      Vector2(size.x * 0.5, size.y * 0.47),
      anchor: Anchor.center,
    );
    _picture = recorder.endRecording();
    _cachedSize = size;
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (_cachedSize != size || _picture == null) _rebuild(size);
    canvas.drawPicture(_picture!);
  }
}

class DustLayer extends Component with HasGameReference<DdzTableGame> {
  DustLayer() : _random = math.Random(7);

  final math.Random _random;
  final List<_Dust> _particles = [];
  final Paint _paint = Paint()
    ..color = const Color(0xFFEBD6A4).withValues(alpha: 0.10);
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
      canvas.drawCircle(
        Offset(x, particle.y * size.y),
        particle.radius,
        _paint,
      );
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
