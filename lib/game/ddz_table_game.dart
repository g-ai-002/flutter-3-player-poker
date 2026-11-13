import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/playing_card.dart';
import '../theme/app_theme.dart';
import 'logic_clock.dart';
import 'play_flight.dart';
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

  /// 三家在牌桌上的几何，由 Flutter 布局回传；未回传前使用经验位置。
  final Map<int, PlayerTarget> _targets = {};

  /// 几何没变时不重复回传，避免每帧刷新时做无意义的布局查询与分配。
  void setTargets(Map<int, PlayerTarget> targets) {
    if (mapEquals(_targets, targets)) return;
    _targets
      ..clear()
      ..addAll(targets);
  }

  /// 起飞点：优先使用座位回传的头像（人类玩家为手牌）位置。
  Offset seatPoint(int player) {
    final seat = _targets[player]?.seat;
    if (seat != null) return Offset(seat.dx * size.x, seat.dy * size.y);
    return switch (player) {
      1 => Offset(size.x * 0.86, size.y * 0.26),
      2 => Offset(size.x * 0.14, size.y * 0.26),
      _ => Offset(size.x * 0.5, size.y * 0.84),
    };
  }

  /// 飞牌落点：优先使用布局回传的真实出牌区中心。
  Offset pilePoint(int player) {
    final target = _targets[player];
    if (target != null) {
      return Offset(target.center.dx * size.x, target.center.dy * size.y);
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
        _playCards(event);
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

  /// 出牌动画：每张牌各飞一次，数量与本次出牌完全一致。
  ///
  /// 落点按出牌区的真实叠放规则排布，尺寸对齐牌桌上牌面的实际显示尺寸，
  /// 因此取消飞行后由牌桌原位接管，不会出现缩放或位移的跳变。
  void _playCards(TableEvent event) {
    final cards = event.cards;
    if (cards.isEmpty) return;
    final target = _targets[event.player];
    final cardSize = target?.cardSize ?? const Size(34, 47.6);
    final spacing = PlayFlight.spacing(
      count: cards.length,
      cardWidth: cardSize.width,
      maxWidth: target?.maxWidth ?? cardSize.width * cards.length,
    );
    final stackWidth = cardSize.width + spacing * (cards.length - 1);
    final center = pilePoint(event.player);
    final from = seatPoint(event.player);
    for (var i = 0; i < cards.length; i++) {
      add(
        CardFlight(
          card: cards[i],
          from: from,
          to: Offset(
            center.dx - stackWidth / 2 + cardSize.width / 2 + i * spacing,
            center.dy,
          ),
          size: cardSize,
          angle: target?.angle ?? 0,
          delay: i * PlayFlight.stagger,
        ),
      );
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
            size: const Size(30, 42),
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
    // 浮尘直接烘进绒面图片：外观不变，但每帧不再有 22 次圆形绘制与粒子推进。
    final dust = Paint()
      ..color = const Color(0xFFEBD6A4).withValues(alpha: 0.1);
    final random = math.Random(7);
    for (var i = 0; i < 22; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.x, random.nextDouble() * size.y),
        0.6 + random.nextDouble() * 1.6,
        dust,
      );
    }
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

class CardFlight extends Component {
  CardFlight({
    required this.card,
    required this.from,
    required this.to,
    required this.size,
    this.angle = 0,
    this.delay = 0,
    this.duration = PlayFlight.duration,
  });

  final PlayingCard? card;
  final Offset from;
  final Offset to;

  /// 落定时的单张牌尺寸：与牌桌出牌区上牌面的实际尺寸一致。
  final Size size;

  /// 落定时的倾斜角度：左右两家的牌堆朝自家座位倾斜。
  final double angle;

  double delay;
  final double duration;
  double _elapsed = 0;

  /// 起飞时为落定尺寸的 58%，飞向牌桌的过程中放大到出牌区的大小。
  static const double _startScale = 0.58;

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
    final arc = math.sin(t * math.pi) * (size.height * 0.34);
    final width = size.width * (_startScale + (1 - _startScale) * t);
    if (width <= 0) return;
    final scale = width / CardArt.width;
    final center = Offset(position.dx, position.dy - arc);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle * t);
    canvas.scale(scale);
    canvas.translate(-CardArt.width / 2, -CardArt.height / 2);
    // 牌面文字与画刷全部预先合成为图片，飞行期间每帧只提交一次绘制。
    canvas.drawPicture(CardArt.pictureOf(card));
    canvas.restore();
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

  /// 冲击波每帧只改颜色与线宽，画刷本身复用，避免动画期间反复分配。
  final Paint _outer = Paint()..style = PaintingStyle.stroke;
  final Paint _inner = Paint()..style = PaintingStyle.stroke;

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
    _outer
      ..strokeWidth = 4 * (1 - t) + 1
      ..color = color.withValues(alpha: alpha);
    canvas.drawCircle(position, radius, _outer);
    _inner
      ..strokeWidth = 2
      ..color = const Color(0xFFEBD6A4).withValues(alpha: alpha * 0.8);
    canvas.drawCircle(position, radius * 0.65, _inner);
  }
}

/// 牌面预渲染缓存：同一张牌的文字排版、渐变与描边只做一次。
///
/// 飞行动画以前每帧都要重排点数与花色文字并新建画刷，现在每帧只
/// 提交一张 [ui.Picture]，牌多时（发牌、飞机、连对）帧率更稳。
abstract final class CardArt {
  static const double width = 34;
  static const double height = width * PlayFlight.cardAspect;
  static const Rect _rect = Rect.fromLTWH(0, 0, width, height);
  static final RRect _card = RRect.fromRectAndRadius(
    _rect,
    const Radius.circular(5),
  );
  static final Map<int, ui.Picture> _faces = {};
  static ui.Picture? _back;

  static ui.Picture pictureOf(PlayingCard? card) =>
      card == null ? back() : face(card);
  static ui.Picture face(PlayingCard card) =>
      _faces.putIfAbsent(card.id, () => _record(card));
  static ui.Picture back() => _back ??= _record(null);

  static Paint _stroke(Color color, double width) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..color = color;
  static TextPaint _text(double size, Color color, {FontWeight? weight}) =>
      TextPaint(
        style: TextStyle(
          fontSize: size,
          height: 1,
          fontWeight: weight,
          color: color,
        ),
      );

  static ui.Picture _record(PlayingCard? card) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (card == null) {
      canvas.drawRRect(
        _card,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF1B5C3C), Color(0xFF0C2B1C)],
          ).createShader(_rect),
      );
      canvas.drawRRect(_card, _stroke(const Color(0x99D8B56A), 1));
      return recorder.endRecording();
    }
    canvas.drawRRect(_card, Paint()..color = kCardFaceTop);
    canvas.drawRRect(_card, _stroke(kCardBorder, 0.8));
    final color = card.isRed ? kCardRed : kCardBlack;
    _text(
      13,
      color,
      weight: FontWeight.w800,
    ).render(canvas, card.rankLabel, Vector2(_rect.left + 3, _rect.top + 2));
    if (card.isJoker) {
      _text(15, color).render(
        canvas,
        card.rank == 17 ? '大' : '小',
        Vector2(_rect.left + 3, _rect.top + 18),
      );
    } else {
      _text(15, color).render(
        canvas,
        card.suitSymbol,
        Vector2(_rect.center.dx, _rect.center.dy + 3),
        anchor: Anchor.center,
      );
    }
    return recorder.endRecording();
  }

  /// 测试用：已缓存的牌面数量。
  @visibleForTesting
  static int get cachedFaces => _faces.length;

  /// 测试用：释放缓存，避免测试之间互相影响。
  @visibleForTesting
  static void clearCache() {
    for (final picture in _faces.values) {
      picture.dispose();
    }
    _faces.clear();
    _back?.dispose();
    _back = null;
  }
}
