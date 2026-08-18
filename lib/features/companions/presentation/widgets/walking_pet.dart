import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CartoonPetType { cat, dog, crab, bunny }

class WalkingPet extends StatefulWidget {
  const WalkingPet({super.key});

  @override
  State<WalkingPet> createState() => _WalkingPetState();
}

class _WalkingPetState extends State<WalkingPet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // State
  int _currentTypeIndex = 0;
  final List<CartoonPetType> _types = CartoonPetType.values;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePet() {
    setState(() {
      _currentTypeIndex = (_currentTypeIndex + 1) % _types.length;
    });
  }

  CartoonPetType get _currentType => _types[_currentTypeIndex];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double t = _controller.value;

            // Walk across screen: -60 to maxWidth + 60
            final double x = (t * (maxWidth + 120)) - 60;

            // Bobbing animation for walking effect
            final double walkCycle = math.sin(t * 80 * math.pi);
            final double bob = walkCycle.abs() * 4;
            final double legAngle = walkCycle * 0.5; // Leg swing

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: x,
                  top: bob + 5,
                  child: GestureDetector(
                    onTap: _togglePet,
                    child: Tooltip(
                      message: 'Tap to switch pet',
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: CustomPaint(
                          painter: _CartoonPetPainter(
                            type: _currentType,
                            legAngle: legAngle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CartoonPetPainter extends CustomPainter {
  _CartoonPetPainter({required this.type, required this.legAngle});

  final CartoonPetType type;
  final double legAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final double w = size.width;
    final double h = size.height;

    // Center point
    final Offset center = Offset(w / 2, h / 2);

    switch (type) {
      case CartoonPetType.cat:
        _drawCat(canvas, center, w, paint);
        break;
      case CartoonPetType.dog:
        _drawDog(canvas, center, w, paint);
        break;
      case CartoonPetType.crab:
        _drawCrab(canvas, center, w, paint);
        break;
      case CartoonPetType.bunny:
        _drawBunny(canvas, center, w, paint);
        break;
    }
  }

  void _drawCat(Canvas canvas, Offset center, double size, Paint paint) {
    // Colors
    final Color bodyColor = const Color(0xFF333333); // Black cat
    final Color eyeColor = Colors.white;
    final Color pupilColor = Colors.black;

    // Body
    paint.color = bodyColor;
    final Rect bodyRect = Rect.fromCenter(
      center: center.translate(0, 5),
      width: size * 0.6,
      height: size * 0.4,
    );
    canvas.drawOval(bodyRect, paint);

    // Head
    final Offset headCenter = center.translate(0, -5);
    canvas.drawCircle(headCenter, size * 0.25, paint);

    // Ears
    final Path ears = Path();
    ears.moveTo(headCenter.dx - 8, headCenter.dy - 5);
    ears.lineTo(headCenter.dx - 12, headCenter.dy - 15);
    ears.lineTo(headCenter.dx - 2, headCenter.dy - 8);

    ears.moveTo(headCenter.dx + 8, headCenter.dy - 5);
    ears.lineTo(headCenter.dx + 12, headCenter.dy - 15);
    ears.lineTo(headCenter.dx + 2, headCenter.dy - 8);
    canvas.drawPath(ears, paint);

    // Legs (Animated)
    paint.strokeWidth = 3;
    paint.strokeCap = StrokeCap.round;
    paint.style = PaintingStyle.stroke;

    _drawLeg(canvas, center.translate(-8, 12), legAngle, 8, paint);
    _drawLeg(canvas, center.translate(8, 12), -legAngle, 8, paint);

    // Tail
    paint.style = PaintingStyle.stroke;
    final Path tail = Path();
    tail.moveTo(center.dx - 12, center.dy + 5);
    tail.quadraticBezierTo(
      center.dx - 20,
      center.dy - 5,
      center.dx - 15,
      center.dy - 15,
    );
    canvas.drawPath(tail, paint);

    // Eyes
    paint.style = PaintingStyle.fill;
    paint.color = eyeColor;
    canvas.drawCircle(headCenter.translate(-4, -2), 3, paint);
    canvas.drawCircle(headCenter.translate(4, -2), 3, paint);

    paint.color = pupilColor;
    canvas.drawCircle(headCenter.translate(-4, -2), 1, paint);
    canvas.drawCircle(headCenter.translate(4, -2), 1, paint);
  }

  void _drawDog(Canvas canvas, Offset center, double size, Paint paint) {
    // Shiba Colors
    final Color bodyColor = const Color(0xFFD2691E); // Chocolate/Orange
    final Color whiteColor = const Color(0xFFFFF8E7);

    // Body
    paint.color = bodyColor;
    final Rect bodyRect = Rect.fromCenter(
      center: center.translate(0, 5),
      width: size * 0.65,
      height: size * 0.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(10)),
      paint,
    );

    // Head
    final Offset headCenter = center.translate(0, -6);
    canvas.drawCircle(headCenter, size * 0.26, paint);

    // Snout (White)
    paint.color = whiteColor;
    canvas.drawCircle(headCenter.translate(0, 4), size * 0.12, paint);

    // Ears
    paint.color = bodyColor;
    final Path ears = Path();
    ears.moveTo(headCenter.dx - 8, headCenter.dy - 5);
    ears.lineTo(headCenter.dx - 10, headCenter.dy - 14);
    ears.lineTo(headCenter.dx - 2, headCenter.dy - 8);

    ears.moveTo(headCenter.dx + 8, headCenter.dy - 5);
    ears.lineTo(headCenter.dx + 10, headCenter.dy - 14);
    ears.lineTo(headCenter.dx + 2, headCenter.dy - 8);
    canvas.drawPath(ears, paint);

    // Legs (Animated)
    paint.color = bodyColor;
    paint.strokeWidth = 4;
    paint.strokeCap = StrokeCap.round;
    paint.style = PaintingStyle.stroke;

    _drawLeg(canvas, center.translate(-8, 12), legAngle, 8, paint);
    _drawLeg(canvas, center.translate(8, 12), -legAngle, 8, paint);

    // Tail (Curly)
    final Path tail = Path();
    tail.moveTo(center.dx - 12, center.dy);
    tail.quadraticBezierTo(
      center.dx - 18,
      center.dy - 10,
      center.dx - 12,
      center.dy - 12,
    );
    canvas.drawPath(tail, paint);

    // Face Details
    paint.style = PaintingStyle.fill;
    paint.color = Colors.black;
    canvas.drawCircle(headCenter.translate(-5, -2), 2, paint); // Eye L
    canvas.drawCircle(headCenter.translate(5, -2), 2, paint); // Eye R
    canvas.drawCircle(headCenter.translate(0, 3), 2.5, paint); // Nose
  }

  void _drawCrab(Canvas canvas, Offset center, double size, Paint paint) {
    final Color bodyColor = const Color(0xFFFF6B6B);

    // Body
    paint.color = bodyColor;
    final Rect bodyRect = Rect.fromCenter(
      center: center.translate(0, 5),
      width: size * 0.7,
      height: size * 0.45,
    );
    canvas.drawOval(bodyRect, paint);

    // Eyes (Stalks)
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    paint.color = bodyColor;
    canvas.drawLine(center.translate(-6, 0), center.translate(-10, -10), paint);
    canvas.drawLine(center.translate(6, 0), center.translate(10, -10), paint);

    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center.translate(-10, -10), 3, paint);
    canvas.drawCircle(center.translate(10, -10), 3, paint);

    paint.color = Colors.black;
    canvas.drawCircle(center.translate(-10, -10), 1, paint);
    canvas.drawCircle(center.translate(10, -10), 1, paint);

    // Claws (Animated slightly)
    paint.color = bodyColor;
    double clawOffset = math.sin(legAngle * 2) * 2;

    canvas.drawCircle(center.translate(-18, 0 + clawOffset), 6, paint);
    canvas.drawCircle(center.translate(18, 0 - clawOffset), 6, paint);

    // Legs
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    for (int i = 0; i < 3; i++) {
      double offset = (i - 1) * 6.0;
      double legY = 10.0 + (i % 2 == 0 ? -legAngle * 2 : legAngle * 2);

      // Left legs
      Path lLeg = Path();
      lLeg.moveTo(center.dx - 10, center.dy + 5 + offset);
      lLeg.lineTo(center.dx - 18, center.dy + 10 + offset + legY);
      canvas.drawPath(lLeg, paint);

      // Right legs
      Path rLeg = Path();
      rLeg.moveTo(center.dx + 10, center.dy + 5 + offset);
      rLeg.lineTo(center.dx + 18, center.dy + 10 + offset + legY);
      canvas.drawPath(rLeg, paint);
    }
  }

  void _drawBunny(Canvas canvas, Offset center, double size, Paint paint) {
    final Color bodyColor = Colors.white;
    final Color earInner = const Color(0xFFFFC0CB); // Pink

    // Body
    paint.color = bodyColor;
    final Rect bodyRect = Rect.fromCenter(
      center: center.translate(0, 5),
      width: size * 0.5,
      height: size * 0.4,
    );
    canvas.drawOval(bodyRect, paint);

    // Head
    final Offset headCenter = center.translate(0, -4);
    canvas.drawCircle(headCenter, size * 0.22, paint);

    // Ears
    paint.color = bodyColor;
    final Rect earL = Rect.fromCenter(
      center: headCenter.translate(-5, -12),
      width: 6,
      height: 16,
    );
    final Rect earR = Rect.fromCenter(
      center: headCenter.translate(5, -12),
      width: 6,
      height: 16,
    );
    canvas.drawOval(earL, paint);
    canvas.drawOval(earR, paint);

    // Inner Ears
    paint.color = earInner;
    canvas.drawOval(earL.deflate(1.5), paint);
    canvas.drawOval(earR.deflate(1.5), paint);

    // Legs (Hopping)
    paint.color = bodyColor;
    paint.style = PaintingStyle.fill;
    double hop = math.max(0, -math.sin(legAngle));

    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-6, 12 - hop * 5),
        width: 6,
        height: 8,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(6, 12 - hop * 5),
        width: 6,
        height: 8,
      ),
      paint,
    );

    // Face
    paint.color = Colors.black;
    canvas.drawCircle(headCenter.translate(-4, -2), 1.5, paint);
    canvas.drawCircle(headCenter.translate(4, -2), 1.5, paint);

    paint.color = earInner;
    canvas.drawCircle(headCenter.translate(0, 2), 1.5, paint); // Nose
  }

  void _drawLeg(
    Canvas canvas,
    Offset root,
    double angle,
    double length,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(root.dx, root.dy);
    canvas.rotate(angle);
    canvas.drawLine(Offset.zero, Offset(0, length), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CartoonPetPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.legAngle != legAngle;
  }
}
