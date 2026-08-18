import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

class BreathingPracticePage extends StatefulWidget {
  const BreathingPracticePage({required this.companion, super.key});

  final Companion companion;

  @override
  State<BreathingPracticePage> createState() => _BreathingPracticePageState();
}

class _BreathingPracticePageState extends State<BreathingPracticePage>
    with SingleTickerProviderStateMixin {
  static const int _sessionSeconds = 60;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);
  Timer? _timer;
  int _secondsLeft = _sessionSeconds;
  bool _completed = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        setState(() {
          _secondsLeft = 0;
          _completed = true;
        });
        timer.cancel();
        _completeAndExit(true);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _completeAndExit(bool finished) {
    if (_popped) return;
    _popped = true;
    Navigator.of(context).pop(finished);
  }

  String _phaseLabel(double t) {
    if (t < 0.4) return 'Inhale 4s';
    if (t < 0.6) return 'Hold 2s';
    return 'Exhale 6s';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.companion.primaryColor;
    final String timeLabel =
        '${(_secondsLeft ~/ 60).toString().padLeft(2, '0')}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';
    final double baseSize = (MediaQuery.of(context).size.shortestSide * 0.4)
        .clamp(140.0, 220.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('1-minute breathing'),
        leading: BackButton(onPressed: () => Navigator.of(context).pop(false)),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Follow the orb: inhale 4s, hold 2s, exhale 6s. Keep shoulders soft.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final double t = _pulseController.value;
                    final double scale = 0.8 + (0.28 * math.sin(t * math.pi));
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: baseSize * scale,
                          height: baseSize * scale,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                accent.withValues(alpha: 0.9),
                                accent.withValues(alpha: 0.2),
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: accent.withValues(alpha: 0.4),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _phaseLabel(t),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Time left $timeLabel',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 240,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: 1 - (_secondsLeft / _sessionSeconds),
                              minHeight: 6,
                              backgroundColor: Colors.grey.withValues(
                                alpha: 0.25,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                accent.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Row(
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => _completeAndExit(true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _completed ? 'Done, go back' : 'Finish and return',
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _completed
                      ? 'Nice work, you have earned a leaf.'
                      : 'Stay with me until 00:00 to auto-complete.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
