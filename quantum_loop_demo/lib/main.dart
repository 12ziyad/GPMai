// lib/main.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:ui' show lerpDouble;

void main() => runApp(const QuantumBlueprintApp());

class QuantumBlueprintApp extends StatelessWidget {
  const QuantumBlueprintApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantum Blueprint — Human Demo',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: SafeArea(child: BlueprintView())),
    );
  }
}

class BlueprintView extends StatefulWidget {
  const BlueprintView({super.key});
  @override
  State<BlueprintView> createState() => _BlueprintViewState();
}

class _BlueprintViewState extends State<BlueprintView> with SingleTickerProviderStateMixin {
  Offset center = Offset.zero; // world center
  double scale = 1.0;

  // smoothing
  Offset _targetCenter = Offset.zero;
  double _targetScale = 1.0;
  final double _smoothing = 0.22;

  Offset? lastFocal;
  late final AnimationController _tick;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(vsync: this, duration: const Duration(seconds: 1000))..repeat();
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  void _applySmoothing() {
    scale = lerpDouble(scale, _targetScale, _smoothing)!;
    center = Offset.lerp(center, _targetCenter, _smoothing)!;
  }

  void _onScaleStart(ScaleStartDetails s) {
    lastFocal = s.focalPoint;
    _targetCenter = center;
    _targetScale = scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, Size size) {
    if (d.scale != 1.0) {
      final focal = d.focalPoint;
      final before = _deviceToWorld(focal, size, scaleOverride: _targetScale);
      _targetScale = (_targetScale * d.scale).clamp(0.45, 6.0);
      final after = _deviceToWorld(focal, size, scaleOverride: _targetScale);
      _targetCenter += (before - after);
    } else if (d.focalPointDelta != Offset.zero) {
      final pan = d.focalPointDelta / (scale * 1.5);
      _targetCenter -= pan;
    }
    _applySmoothing();
    setState(() {});
  }

  Offset _deviceToWorld(Offset device, Size size, {double? scaleOverride}) {
    final s = scaleOverride ?? _targetScale;
    final centerScreen = Offset(size.width / 2, size.height / 2);
    return _targetCenter + (device - centerScreen) / s;
  }

  void _onTapUp(TapUpDetails d, Size size) {
    // if user taps near heart, smoothly center and zoom in
    final worldTap = _deviceToWorld(d.localPosition, size);
    final heartPos = const Offset(0, -60);
    final dist = (worldTap - heartPos).distance;
    if (dist < 60 / scale) {
      _targetCenter = heartPos;
      _targetScale = 3.8; // zoom in
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, cons) {
      final size = Size(cons.maxWidth, cons.maxHeight);
      return GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: (d) => _onScaleUpdate(d, size),
        onTapUp: (t) => _onTapUp(t, size),
        child: AnimatedBuilder(
          animation: _tick,
          builder: (_, __) {
            _applySmoothing();
            return CustomPaint(
              size: size,
              painter: BlueprintPainter(center: center, scale: scale, time: _tick.lastElapsedDuration ?? Duration.zero),
            );
          },
        ),
      );
    });
  }
}

class BlueprintPainter extends CustomPainter {
  final Offset center;
  final double scale;
  final Duration time;
  BlueprintPainter({required this.center, required this.scale, required this.time});

  final Paint bg = Paint()..color = const Color(0xFF052033);

  @override
  void paint(Canvas canvas, Size size) {
    // background
    canvas.drawRect(Offset.zero & size, bg);

    // camera transform (world to screen)
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, scale);
    canvas.translate(-center.dx, -center.dy);

    // grid
    _drawGrid(canvas, size);

    // human center
    final humanPos = const Offset(0, 20);
    _drawHumanSkeleton(canvas, humanPos);

    // heart
    final heartPos = const Offset(0, -60);
    _drawHeart(canvas, heartPos, baseSize: 3.6);

    // draw labels and side UI in screen-space
    canvas.restore();
    _drawLabelsAndUI(canvas, size, humanPos, heartPos);

    // if heart is zoomed large, draw a center overlay detail
    final heartScreenRadius = (20.0 * scale).abs();
    if (heartScreenRadius > 120.0) {
      // place overlay centered
      _drawHeartOverlay(canvas, size);
    }
  }

  // GRID
  void _drawGrid(Canvas canvas, Size size) {
    final spacing = 48.0;
    final left = -2000.0, right = 2000.0, top = -2000.0, bottom = 2000.0;
    final thin = Paint()..color = const Color(0xFF4A7A94).withOpacity(0.10)..strokeWidth = 1.0 / scale;
    final thick = Paint()..color = const Color(0xFF78B4DC).withOpacity(0.18)..strokeWidth = 1.6 / scale;

    for (double x = left; x <= right; x += spacing) {
      final idx = (x / spacing).round().abs();
      canvas.drawLine(Offset(x, top), Offset(x, bottom), (idx % 5 == 0) ? thick : thin);
    }
    for (double y = top; y <= bottom; y += spacing) {
      final idx = (y / spacing).round().abs();
      canvas.drawLine(Offset(left, y), Offset(right, y), (idx % 5 == 0) ? thick : thin);
    }
  }

  // HUMAN: polished wireframe skeleton (procedural)
  // REPLACE the previous _drawHumanSkeleton with this corrected version
void _drawHumanSkeleton(Canvas canvas, Offset pos) {
  canvas.save();
  canvas.translate(pos.dx, pos.dy);
  final Paint outline = Paint()
    ..color = const Color(0xFFDCEFF4)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.2, 2.0 / scale)
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  // head
  final headRect = Rect.fromCenter(center: const Offset(0.0, -200.0), width: 78.0, height: 96.0);
  canvas.drawOval(headRect, outline);

  // neck and clavicle
  final neck = Path();
  neck.moveTo(-18.0, -160.0);
  neck.quadraticBezierTo(0.0, -144.0, 18.0, -160.0);
  canvas.drawPath(neck, outline);

  final clav = Path();
  clav.moveTo(-68.0, -140.0);
  clav.quadraticBezierTo(-20.0, -120.0, 0.0, -120.0);
  clav.quadraticBezierTo(20.0, -120.0, 68.0, -140.0);
  canvas.drawPath(clav, outline);

  // ribcage (rounded)
  final ribs = Path();
  ribs.moveTo(-48.0, -110.0);
  ribs.cubicTo(-70.0, -60.0, -66.0, -10.0, -40.0, 40.0);
  ribs.lineTo(-24.0, 84.0);
  ribs.cubicTo(-12.0, 106.0, 12.0, 106.0, 24.0, 84.0);
  ribs.lineTo(40.0, 40.0);
  ribs.cubicTo(66.0, -10.0, 70.0, -60.0, 48.0, -110.0);
  canvas.drawPath(ribs, outline);

  // spine
  final spine = Paint()
    ..color = const Color(0xFFBDEFF6)
    ..strokeWidth = max(0.9, 1.0 / scale)
    ..style = PaintingStyle.stroke;
  canvas.drawLine(const Offset(0.0, -120.0), const Offset(0.0, 170.0), spine);

  // pelvis
  final pelvis = Path();
  pelvis.moveTo(-44.0, 170.0);
  pelvis.quadraticBezierTo(0.0, 210.0, 44.0, 170.0);
  pelvis.lineTo(20.0, 200.0);
  pelvis.lineTo(-20.0, 200.0);
  canvas.drawPath(pelvis, outline);

  // arms
  final limb = Paint()
    ..color = const Color(0xFFDCEFF4)
    ..strokeWidth = max(1.6, 2.0 / scale)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  final leftArm = Path();
  leftArm.moveTo(-60.0, -115.0);
  leftArm.cubicTo(-110.0, -90.0, -120.0, -30.0, -120.0, 10.0);
  leftArm.cubicTo(-118.0, 38.0, -100.0, 62.0, -84.0, 86.0);
  canvas.drawPath(leftArm, limb);

  final rightArm = Path();
  rightArm.moveTo(60.0, -115.0);
  rightArm.cubicTo(110.0, -90.0, 120.0, -30.0, 120.0, 10.0);
  rightArm.cubicTo(118.0, 38.0, 100.0, 62.0, 84.0, 86.0);
  canvas.drawPath(rightArm, limb);

  // legs
  final leftLeg = Path();
  leftLeg.moveTo(-20.0, 200.0);
  leftLeg.cubicTo(-28.0, 260.0, -36.0, 320.0, -28.0, 380.0);
  canvas.drawPath(leftLeg, limb);

  final rightLeg = Path();
  rightLeg.moveTo(20.0, 200.0);
  rightLeg.cubicTo(28.0, 260.0, 36.0, 320.0, 28.0, 380.0);
  canvas.drawPath(rightLeg, limb);

  // subtle rib lines inside ribcage
  outline.strokeWidth = max(0.9, 1.0 / scale);
  for (int i = 0; i < 6; i++) {
    final double y = -84.0 + i * 24.0;
    final rib = Path();
    rib.moveTo(-36.0, y);
    rib.quadraticBezierTo(0.0, y - 6.0, 36.0, y);
    canvas.drawPath(rib, outline);
  }

  canvas.restore();
}
  // HEART: pulsing glowing heart (procedural)
  void _drawHeart(Canvas canvas, Offset pos, {double baseSize = 3.4}) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    final t = time.inMilliseconds / 1000.0;
    final pulse = 1.0 + (sin(t * 2.2) * 0.06) + (sin(t * 5.1) * 0.02);
    final scaleFactor = (baseSize / 20.0) * pulse;
    canvas.scale(scaleFactor);

    // glow rings (red)
    for (int i = 5; i >= 1; i--) {
      final alpha = (0.06 * i).clamp(0.0, 0.36);
      final gp = Path()..addPath(_heartPath(20.0 + i * 6.0), Offset.zero);
      final gpPaint = Paint()
        ..color = Color.fromARGB((alpha * 255).toInt(), 255, 82, 82)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      canvas.drawPath(gp, gpPaint);
    }

    final fill = Paint()..color = const Color(0xFFFF6B6B);
    final stroke = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 / scale
      ..isAntiAlias = true;

    canvas.drawPath(_heartPath(20.0), fill);
    canvas.drawPath(_heartPath(20.0), stroke);

    // small vessel hints
    final v = Paint()
      ..color = const Color(0xFFB33A3A)
      ..strokeWidth = 1.2 / scale
      ..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..moveTo(-8, -6)..cubicTo(-14, -12, -14, -22, -6, -28), v);
    canvas.drawPath(Path()..moveTo(8, -6)..cubicTo(14, -12, 14, -22, 6, -28), v);

    canvas.restore();
  }

  Path _heartPath(double r) {
    final p = Path();
    p.moveTo(0, -r * 0.28);
    p.cubicTo(-r, -r * 0.86, -r * 1.05, r * 0.36, 0, r * 1.04);
    p.cubicTo(r * 1.05, r * 0.36, r, -r * 0.86, 0, -r * 0.28);
    p.close();
    return p;
  }

  // screen-space labels and sidebar UI
  void _drawLabelsAndUI(Canvas canvas, Size size, Offset humanWorld, Offset heartWorld) {
    final textColor = const Color(0xFFBFE8FF);
    final labelStyle = TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500);
    // compute screen pos of body features
    final centerScreen = Offset(size.width / 2, size.height / 2);
    final humanScreen = centerScreen + (humanWorld - center) * scale;
    final heartScreen = centerScreen + (heartWorld - center) * scale;

    // Labels: Heart (to right with pointer)
    _drawLabel(canvas, heartScreen + const Offset(80, -10), 'Heart', heartScreen, labelStyle);
    // Lungs
    _drawLabel(canvas, Offset(humanScreen.dx - 120, humanScreen.dy - 20), 'Lungs', humanScreen + const Offset(-30, -10), labelStyle);
    // Stomach
    _drawLabel(canvas, Offset(humanScreen.dx - 110, humanScreen.dy + 80), 'Stomach', humanScreen + const Offset(-10, 60), labelStyle);
    // Skeleton
    _drawLabel(canvas, Offset(humanScreen.dx - 130, humanScreen.dy + 220), 'Skeleton', humanScreen + const Offset(-10, 200), labelStyle);

    // side UI box
    final uiW = min(220.0, size.width * 0.22);
    final uiH = min(320.0, size.height * 0.46);
    final uiRect = Rect.fromLTWH(size.width - uiW - 18, size.height / 2 - uiH / 2, uiW, uiH);
    final uiBg = Paint()..color = Colors.black.withOpacity(0.22);
    canvas.drawRRect(RRect.fromRectAndRadius(uiRect, const Radius.circular(12)), uiBg);

    final menuStyle = TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14);
    final entries = ['Zoom Deeper into Cells', 'View Blood Flow', 'Add Nervous System', '', 'Freeze Simulation'];
    double y = uiRect.top + 18;
    for (var e in entries) {
      final tp = TextPainter(text: TextSpan(text: e, style: menuStyle), textDirection: TextDirection.ltr);
      tp.layout(maxWidth: uiRect.width - 24);
      tp.paint(canvas, Offset(uiRect.left + 12, y));
      y += tp.height + 14;
    }
  }

  void _drawLabel(Canvas canvas, Offset textPos, String label, Offset anchor, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: label, style: style), textDirection: TextDirection.ltr);
    tp.layout();
    // draw pointer line
    final linePaint = Paint()..color = Colors.white.withOpacity(0.85)..strokeWidth = 1.0;
    canvas.drawLine(anchor, textPos + Offset(0, tp.height / 2), linePaint);
    // background pill
    final pillRect = RRect.fromRectAndRadius(Rect.fromLTWH(textPos.dx - 6, textPos.dy - 4, tp.width + 12, tp.height + 8), const Radius.circular(6));
    canvas.drawRRect(pillRect, Paint()..color = const Color(0xFF04324A).withOpacity(0.8));
    tp.paint(canvas, textPos + const Offset(0, 0));
  }

  // overlay: centered heart detailed pane
  void _drawHeartOverlay(Canvas canvas, Size size) {
    final overlayW = min(520.0, size.width * 0.86);
    final overlayH = min(360.0, size.height * 0.62);
    final box = Rect.fromCenter(center: Offset(size.width / 2, size.height / 2), width: overlayW, height: overlayH);
    final bg = Paint()..color = Colors.black.withOpacity(0.44);
    canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(18)), bg);

    // inner content
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(box.deflate(14), const Radius.circular(12)));
    final contentCenter = box.center;
    canvas.translate(contentCenter.dx, contentCenter.dy - 10);

    final detailScale = min(box.width, box.height) / 320.0;
    canvas.scale(detailScale);

    // layered heart anatomy (procedural)
    for (int i = 4; i >= 1; i--) {
      final p = _heartPath(36.0 + i * 8.0);
      final layer = Paint()
        ..color = Color.fromARGB((40 + i * 40).clamp(0, 255), 240, (80 + i * 12).clamp(0, 255), 80)
        ..style = PaintingStyle.fill;
      canvas.drawPath(p, layer);
    }

    // vessels
    final vessel = Paint()..color = const Color(0xFF4A2D2D)..strokeWidth = 3.0..style = PaintingStyle.stroke;
    canvas.drawPath(Path()..moveTo(-10, -6)..cubicTo(-30, -6, -58, 6, -36, 48), vessel);
    canvas.drawPath(Path()..moveTo(10, -6)..cubicTo(30, -6, 58, 6, 36, 48), vessel);

    // label
    final lbl = TextPainter(text: TextSpan(text: 'Cardiac Core — Heart', style: TextStyle(color: const Color(0xFFFFEAEA), fontSize: 20, fontWeight: FontWeight.w700)), textDirection: TextDirection.ltr);
    lbl.layout();
    lbl.paint(canvas, Offset(-box.width * 0.18, box.height * 0.26));

    canvas.restore();

    // small hint
    final hint = TextPainter(text: TextSpan(text: 'Pinch out to zoom deeper • Tap background to exit', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)), textDirection: TextDirection.ltr);
    hint.layout();
    hint.paint(canvas, Offset(box.left + 18, box.bottom - 34));
  }

  @override
  bool shouldRepaint(covariant BlueprintPainter old) {
    return old.center != center || old.scale != scale || old.time != time;
  }
}
