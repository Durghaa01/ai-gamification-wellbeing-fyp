import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

class PersonaBackdrop extends StatelessWidget {
  const PersonaBackdrop({
    super.key,
    required this.companion,
    required this.typingIntensity,
  });

  final Companion companion;
  final double typingIntensity;

  @override
  Widget build(BuildContext context) {
    final Widget background = switch (companion.persona) {
      CompanionPersona.listener => _ListenerBackdrop(
        key: const ValueKey('listener_backdrop'),
        primary: companion.primaryColor,
        secondary: companion.secondaryColor,
        intensity: typingIntensity,
      ),
      CompanionPersona.coach => _CoachBackdrop(
        key: const ValueKey('coach_backdrop'),
        primary: companion.primaryColor,
        secondary: companion.secondaryColor,
      ),
      CompanionPersona.planner => _PlannerBackdrop(
        key: const ValueKey('planner_backdrop'),
        primary: companion.primaryColor,
        secondary: companion.secondaryColor,
      ),
      CompanionPersona.cheerleader => _CheerBackdrop(
        key: const ValueKey('cheer_backdrop'),
        primary: companion.primaryColor,
        secondary: companion.secondaryColor,
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 440),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: background,
    );
  }
}

class _ListenerBackdrop extends StatefulWidget {
  const _ListenerBackdrop({
    super.key,
    required this.primary,
    required this.secondary,
    required this.intensity,
  });

  final Color primary;
  final Color secondary;
  final double intensity;

  @override
  State<_ListenerBackdrop> createState() => _ListenerBackdropState();
}

class _ListenerBackdropState extends State<_ListenerBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double t = _controller.value * 2 * math.pi;
          final double t2 = (t * 0.7) % (2 * math.pi);
          final double t3 = (t * 1.3) % (2 * math.pi);
          final double intensity = widget.intensity.clamp(0.0, 1.0);
          final double baseOpacity = 0.2 + intensity * 0.35;
          final double radiusScale = 1 + intensity * 0.25;
          return Stack(
            children: <Widget>[
              Positioned.fill(
                child: CustomPaint(
                  painter: _RipplePainter(
                    progress: _controller.value,
                    baseColor: widget.secondary,
                    intensity: intensity,
                  ),
                ),
              ),
              _softCircle(
                alignment: Alignment(
                  0.15 + 0.08 * math.sin(t),
                  0.1 + 0.04 * math.cos(t),
                ),
                radius: 320 * radiusScale,
                color: widget.primary,
                opacity: baseOpacity,
              ),
              _softCircle(
                alignment: Alignment(
                  -0.55 + 0.06 * math.cos(t2),
                  -0.25 + 0.05 * math.sin(t2),
                ),
                radius: 220 * radiusScale,
                color: widget.secondary,
                opacity: baseOpacity * 0.8,
              ),
              _softCircle(
                alignment: Alignment(
                  0.6 + 0.05 * math.sin(t3),
                  -0.3 + 0.03 * math.cos(t3),
                ),
                radius: 260 * radiusScale,
                color: widget.primary,
                opacity: baseOpacity * 0.6,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _softCircle({
    required Alignment alignment,
    required double radius,
    required Color color,
    double opacity = 0.24,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.progress,
    required this.baseColor,
    required this.intensity,
  });

  final double progress;
  final Color baseColor;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width * 0.4, size.height * 0.55);
    final double maxRadius = size.shortestSide * (0.45 + 0.25 * intensity);
    final int waveCount = 4;
    for (int i = 0; i < waveCount; i++) {
      final double phase = ((progress + i / waveCount) % 1.0);
      final double radius = maxRadius * phase;
      final double opacity =
          (1 - phase).clamp(0.0, 1.0) * (0.18 + intensity * 0.35);
      if (radius <= 0 || opacity <= 0.01) continue;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 + intensity * 4
        ..color = baseColor.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        (oldDelegate.intensity - intensity).abs() > 0.001;
  }
}

class _CoachBackdrop extends StatefulWidget {
  const _CoachBackdrop({
    super.key,
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

  @override
  State<_CoachBackdrop> createState() => _CoachBackdropState();
}

class _CoachBackdropState extends State<_CoachBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double base = _controller.value;
          return LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double height = constraints.maxHeight;

              List<Widget> stripes = <Widget>[];
              for (int i = -1; i < 3; i++) {
                final double progress = (base + i * 0.2) % 1.0;
                final double dx = (progress * 2.2) - 1.1;
                stripes.add(
                  Align(
                    alignment: Alignment(dx, -0.4 + i * 0.35),
                    child: Transform.rotate(
                      angle: -math.pi / 9,
                      child: Container(
                        width: width * 1.4,
                        height: height * 0.32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              widget.primary.withValues(alpha: 0),
                              widget.primary.withValues(alpha: 0.18),
                              widget.secondary.withValues(alpha: 0),
                            ],
                            stops: const <double>[0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Stack(children: stripes);
            },
          );
        },
      ),
    );
  }
}

class _PlannerBackdrop extends StatefulWidget {
  const _PlannerBackdrop({
    super.key,
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

  @override
  State<_PlannerBackdrop> createState() => _PlannerBackdropState();
}

class _PlannerBackdropState extends State<_PlannerBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _PlannerGridPainter(
              progress: _controller.value,
              primary: widget.primary,
              secondary: widget.secondary,
            ),
          );
        },
      ),
    );
  }
}

class _PlannerGridPainter extends CustomPainter {
  _PlannerGridPainter({
    required this.progress,
    required this.primary,
    required this.secondary,
  });

  final double progress;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint linePaint = Paint()
      ..color = primary.withValues(alpha: 0.14)
      ..strokeWidth = 1.2;

    final Paint boldPaint = Paint()
      ..color = secondary.withValues(alpha: 0.18)
      ..strokeWidth = 1.6;

    const double spacing = 120;
    final double shift = (progress % 1.0) * spacing;

    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      final double dx = x + shift;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), linePaint);
    }
    for (double y = -spacing; y < size.height + spacing; y += spacing) {
      final double dy = y + shift;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), linePaint);
    }

    // Emphasise a sweeping diagonal path.
    final Path guide = Path()
      ..moveTo(-spacing + shift, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * (0.4 + 0.05 * math.sin(progress * 2 * math.pi)),
        size.width + spacing - shift,
        size.height * 0.85,
      );
    canvas.drawPath(
      guide,
      Paint()
        ..color = secondary.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Highlight intersection nodes.
    for (double x = -spacing; x < size.width + spacing; x += spacing) {
      for (double y = -spacing; y < size.height + spacing; y += spacing) {
        final Offset point = Offset(x + shift, y + shift);
        if (point.dx < -20 ||
            point.dx > size.width + 20 ||
            point.dy < -20 ||
            point.dy > size.height + 20) {
          continue;
        }
        canvas.drawCircle(point, 3, boldPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlannerGridPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primary != primary ||
        oldDelegate.secondary != secondary;
  }
}

class _CheerBackdrop extends StatefulWidget {
  const _CheerBackdrop({
    super.key,
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;

  @override
  State<_CheerBackdrop> createState() => _CheerBackdropState();
}

class _CheerBackdropState extends State<_CheerBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  final List<_Sparkle> _sparkles = const <_Sparkle>[
    _Sparkle(origin: Alignment(-0.7, 0.9), scale: 1.0, delay: 0.0),
    _Sparkle(origin: Alignment(-0.2, 1.1), scale: 0.8, delay: 0.2),
    _Sparkle(origin: Alignment(0.4, 0.95), scale: 1.1, delay: 0.4),
    _Sparkle(origin: Alignment(0.7, 1.05), scale: 0.7, delay: 0.55),
    _Sparkle(origin: Alignment(0.0, 1.2), scale: 0.9, delay: 0.75),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double base = _controller.value;
          return Stack(
            children: _sparkles.map((sparkle) {
              final double progress = ((base + sparkle.delay) % 1.0);
              final double y = 1.2 - progress * 2.0;
              final double fade = math.min(
                1,
                math.max(0, 1.0 - (progress - 0.2).abs() * 2),
              );
              final double sway =
                  math.sin((base + sparkle.delay) * 2 * math.pi) * 0.1;
              return Align(
                alignment: Alignment(
                  (sparkle.origin.x + sway).clamp(-1.2, 1.2),
                  y,
                ),
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale:
                        sparkle.scale *
                        (0.9 + 0.2 * math.sin(progress * math.pi)),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[
                            widget.secondary.withValues(alpha: 0.85),
                            widget.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _Sparkle {
  const _Sparkle({
    required this.origin,
    required this.scale,
    required this.delay,
  });

  final Alignment origin;
  final double scale;
  final double delay;
}
