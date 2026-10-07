import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'art.dart';
import 'atlas.dart';
import 'clock.dart';
import 'format.dart';
import 'look.dart';
import 'road_geom.dart';
import 'run.dart';
import 'scene.dart';

class RoadView extends StatelessWidget {
  const RoadView({
    super.key,
    required this.clock,
    required this.atlas,
    required this.scene,
    this.onTap,
  });

  final Clock clock;
  final Atlas atlas;
  final Scene scene;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ListenableBuilder(
          listenable: clock,
          builder: (context, _) {
            return CustomPaint(
              painter: WorldPainter(atlas: atlas, scene: scene, now: clock.now),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class WorldPainter extends CustomPainter {
  WorldPainter({required this.atlas, required this.scene, required this.now});

  final Atlas atlas;
  final Scene scene;
  final double now;

  // Visible slice of the world in art units, widened a little so sprites
  // that straddle the edge still draw.
  var _left = 0.0;
  var _right = 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / artHeight;
    if (scale <= 0) return;
    final cam = cameraFor(
      viewWidth: size.width,
      scale: scale,
      focus: scene.camera.focus,
      lanes: scene.spec.lanes,
    );
    _left = cam - 320;
    _right = cam + size.width / scale + 320;
    final shake = _shake();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(shake.dx, shake.dy);
    canvas.translate(-cam * scale, 0);
    canvas.scale(scale);
    _world(canvas);
    canvas.restore();
  }

  bool _near(double x) => x > _left && x < _right;

  void _world(Canvas canvas) {
    final lanes = scene.spec.lanes;
    final imagePaint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, worldWidth(lanes), artHeight),
      Paint()..color = Look.asphalt,
    );
    _asphalt(canvas, lanes, imagePaint);
    _dashes(canvas, lanes);
    _slice(
      canvas,
      atlas[Art.bankLeft],
      const Rect.fromLTWH(0, 0, bankLeftWidth, artHeight),
      const Rect.fromLTWH(0, 0, bankLeftWidth, artHeight),
      imagePaint,
    );
    final endX = finishStart(lanes);
    _slice(
      canvas,
      atlas[Art.finish],
      const Rect.fromLTWH(finishSrcLeft, 0, finishWidth, artHeight),
      Rect.fromLTWH(endX, 0, finishWidth, artHeight),
      imagePaint,
    );
    _sprite(canvas, atlas[Art.tree], const Offset(140, 1250), 250, imagePaint);
    _sprite(
      canvas,
      atlas[Art.hydrant],
      const Offset(575, 1440),
      170,
      imagePaint,
    );
    _sprite(
      canvas,
      atlas[Art.stanchion],
      const Offset(455, 250),
      430,
      imagePaint,
    );
    _sprite(
      canvas,
      atlas[Art.stanchion],
      const Offset(455, 1380),
      430,
      imagePaint,
    );
    _hatches(canvas);
    _barriers(canvas, imagePaint);
    _bird(canvas, imagePaint);
    _cars(canvas, imagePaint);
  }

  void _asphalt(Canvas canvas, int lanes, Paint paint) {
    final image = atlas[Art.lanes];
    final src = Rect.fromLTWH(asphaltSrcLeft, 0, asphaltSrcWidth, artHeight);
    final bounds = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final cut = src.intersect(bounds);
    if (cut.isEmpty) return;
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(bankLeftWidth, 0, lanes * laneWidth, artHeight),
    );
    var x = bankLeftWidth;
    final end = bankLeftWidth + lanes * laneWidth;
    while (x < end) {
      if (x + cut.width > _left && x < _right) {
        canvas.drawImageRect(
          image,
          cut,
          Rect.fromLTWH(x, 0, cut.width, artHeight),
          paint,
        );
      }
      x += cut.width - 2;
    }
    canvas.restore();
  }

  void _dashes(Canvas canvas, int lanes) {
    final paint = Paint()
      ..color = const Color(0xFFE4E0DC)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.butt;
    const dash = 78.0;
    const gap = 52.0;
    for (var i = 1; i < lanes; i++) {
      final x = bankLeftWidth + i * laneWidth;
      if (!_near(x)) continue;
      var y = 16.0;
      while (y < artHeight - 10) {
        final end = math.min(y + dash, artHeight - 8);
        canvas.drawLine(Offset(x, y), Offset(x, end), paint);
        y += dash + gap;
      }
    }
  }

  // A passed manhole turns gold and loses its number; the one the bird
  // stands on stays out of sight under it.
  bool _golden(int index) {
    if (scene.onCarpet) return true;
    final hop = scene.hop;
    if (hop != null) {
      if (index < hop.from) return true;
      return index == hop.from && hop.progress(now) > 0.12;
    }
    if (scene.phase == RoundPhase.wrecked) return index <= scene.lane;
    return index < scene.lane;
  }

  bool _covered(int index) {
    final hop = scene.hop;
    if (hop != null) {
      return !hop.victory && index == hop.to && hop.progress(now) > 0.85;
    }
    if (scene.phase == RoundPhase.wrecked) return index == scene.deathLane;
    return index == scene.lane;
  }

  void _hatches(Canvas canvas) {
    final lanes = scene.spec.lanes;
    final playing = scene.phase != RoundPhase.betting;
    final hop = scene.hop;
    final next = hop != null ? hop.to : scene.lane + 1;
    final pulse = _pulseLane();
    for (var i = 0; i < lanes; i++) {
      final center = Offset(laneCenter(i), hatchY);
      if (!_near(center.dx)) continue;
      if (_golden(i)) {
        _sprite(canvas, atlas[Art.hatchGold], center, hatchHeight, _plain);
        continue;
      }
      if (_covered(i)) continue;
      final alpha = playing && i > next ? 0.5 : 1.0;
      var height = hatchHeight;
      if (i == pulse) height *= 1 + 0.035 * math.sin(now * 6);
      _sprite(canvas, atlas[Art.hatch], center, height, _faded(alpha));
      _label(canvas, formatMult(scene.spec.stepAt(i)), center, alpha);
    }
  }

  final _plain = Paint()..filterQuality = FilterQuality.medium;

  Paint _faded(double alpha) {
    return Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Colors.white.withValues(alpha: alpha);
  }

  void _label(Canvas canvas, String text, Offset center, double alpha) {
    final size = text.length >= 6 ? 80.0 : 96.0;
    final outline = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 12
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF14181D).withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: alpha),
          fontSize: size,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = Offset(center.dx - fill.width / 2, center.dy - fill.height / 2);
    outline.paint(canvas, at);
    fill.paint(canvas, at);
    outline.dispose();
    fill.dispose();
  }

  void _barriers(Canvas canvas, Paint paint) {
    for (final barrier in scene.barriers) {
      final x = laneCenter(barrier.lane);
      if (!_near(x)) continue;
      final fall = barrier.fall(now);
      if (now < barrier.droppedAt) continue;
      final y = barrierY - (1 - fall * fall) * barrierFall;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, barrierY + 70),
            width: barrierWidth * 0.92,
            height: barrierHeight * 0.55,
          ),
          const Radius.circular(24),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.28 * fall),
      );
      _sprite(canvas, atlas[Art.barrier], Offset(x, y), barrierHeight, paint);
    }
  }

  void _cars(Canvas canvas, Paint paint) {
    for (final car in scene.cars) {
      final at = Offset(laneCenter(car.lane), car.y);
      if (!_near(at.dx)) continue;
      _sprite(canvas, atlas[Art.cars[car.sprite]], at, carHeight, paint);
    }
  }

  void _bird(Canvas canvas, Paint paint) {
    final hop = scene.hop;
    final t = hop?.progress(now) ?? 0;
    final dead =
        scene.phase == RoundPhase.wrecked ||
        (hop != null && hop.dies && t >= 0.93);
    final x = scene.birdX(now);
    final bob = dead || hop != null ? 0.0 : math.sin(now * 2.6) * 6;
    final lift = hop == null || dead ? 0.0 : math.sin(t * math.pi) * 70;
    final y = hatchY + bob - lift;

    if (!dead) {
      final height =
          birdHeight * (hop == null ? 1 : 1 + 0.06 * math.sin(t * math.pi));
      _shadow(canvas, x, hatchY + 150, 190 - lift * 0.8, 34);
      _sprite(canvas, atlas[Art.chicken], Offset(x, y), height, paint);
    } else {
      _shadow(canvas, x, hatchY + 70, 280, 34);
      _sprite(
        canvas,
        atlas[Art.chickenDown],
        Offset(x, hatchY + 40),
        290,
        paint,
      );
      final age = scene.phase == RoundPhase.wrecked
          ? now - scene.wreckedAt
          : 0.0;
      if (age >= 0 && age < 1.1) {
        final fade = Paint()
          ..filterQuality = FilterQuality.medium
          ..color = Colors.white.withValues(
            alpha: (1 - age / 1.1).clamp(0.0, 1.0).toDouble(),
          );
        _sprite(
          canvas,
          atlas[Art.feathers],
          Offset(x, hatchY - 20),
          760 * (0.72 + age * 0.35),
          fade,
          turn: age * 0.5,
        );
      }
    }

    _badge(canvas, x);
  }

  void _badge(Canvas canvas, double x) {
    final index = _badgeLane();
    if (index == null) return;
    final painter = TextPainter(
      text: TextSpan(
        text: formatMult(scene.spec.stepAt(index)),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 72,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: Offset(x, hatchY + 262),
      width: painter.width + 56,
      height: painter.height + 28,
    );
    final fill = Paint()..color = const Color(0xFF3F5A8C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.shift(const Offset(0, 8)),
        const Radius.circular(14),
      ),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      fill,
    );
    final tip = Path()
      ..moveTo(x - 30, rect.top + 1)
      ..lineTo(x, rect.top - 28)
      ..lineTo(x + 30, rect.top + 1)
      ..close();
    canvas.drawPath(tip, fill);
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
    painter.dispose();
  }

  int? _badgeLane() {
    final phase = scene.phase;
    if (phase == RoundPhase.betting ||
        phase == RoundPhase.wrecked ||
        phase == RoundPhase.cashed ||
        scene.onCarpet) {
      return null;
    }
    final hop = scene.hop;
    if (hop != null && hop.dies && hop.progress(now) > 0.7) return null;
    if (hop != null && !hop.dies && !hop.victory && hop.progress(now) > 0.45) {
      return hop.to;
    }
    if (scene.lane >= 0 && scene.lane < scene.spec.lanes) return scene.lane;
    return null;
  }

  int? _pulseLane() {
    final phase = scene.phase;
    if (phase == RoundPhase.wrecked || phase == RoundPhase.cashed) return null;
    if (phase == RoundPhase.betting) return 0;
    if (phase == RoundPhase.hopping) return null;
    final next = scene.lane + 1;
    if (next >= 0 && next < scene.spec.lanes) return next;
    return null;
  }

  Offset _shake() {
    if (scene.phase != RoundPhase.wrecked) return Offset.zero;
    final age = now - scene.wreckedAt;
    if (age < 0 || age > 0.4) return Offset.zero;
    final mag = (1 - age / 0.4) * 6;
    return Offset(math.sin(now * 48) * mag, math.cos(now * 41) * mag);
  }

  void _shadow(Canvas canvas, double x, double y, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y), width: w, height: h),
      Paint()..color = const Color(0x44000000),
    );
  }

  void _sprite(
    Canvas canvas,
    ui.Image image,
    Offset center,
    double height,
    Paint paint, {
    double turn = 0,
  }) {
    final width = height * image.width / image.height;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (turn != 0) canvas.rotate(turn);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      paint,
    );
    canvas.restore();
  }

  void _slice(Canvas canvas, ui.Image image, Rect src, Rect dst, Paint paint) {
    final bounds = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final cut = src.intersect(bounds);
    if (cut.width <= 0 || cut.height <= 0) return;
    canvas.drawImageRect(image, cut, dst, paint);
  }

  @override
  bool shouldRepaint(WorldPainter oldDelegate) => true;
}
