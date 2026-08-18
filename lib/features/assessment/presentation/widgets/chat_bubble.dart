import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/features/assessment/domain/models/assessment.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});
  final AssessmentMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AgentRole.user;
    final bg = isUser
        ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
        : Theme.of(context).cardColor;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(12),
          margin: EdgeInsets.only(
            left: isUser ? 64 : 0,
            right: isUser ? 0 : 64,
            top: 6,
            bottom: 2,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
          ),
          child: _buildContent(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Opacity(
            opacity: 0.7,
            child: Text(
              _fmt(message.ts),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final meta = message.meta ?? const <String, dynamic>{};
    if (meta['type'] == 'report' && meta['score'] != null) {
      final isPhq9 = (meta['scale']?.toString() ?? '') == 'phq9';
      final maxScore = isPhq9 ? 27 : 21;
      final score = _toInt(meta['score']);
      final severity = meta['severity']?.toString() ?? '';
      final range = meta['range']?.toString() ?? '';
      final barValue = (score.clamp(0, maxScore)) / maxScore;
      final color = _severityColor(context, severity, isPhq9);
      final historyList = meta['history'];
      final hasHistory = historyList is List && historyList.length >= 2;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message.text, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: barValue,
              color: color,
              backgroundColor: Theme.of(context).dividerColor.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: $score / $maxScore'),
              Text('Severity: ${_severityEn(severity, isPhq9)} ($range)'),
            ],
          ),
          if (hasHistory) ...[
            const SizedBox(height: 12),
            _buildHistoryMiniChart(context, meta, maxScore),
          ],
        ],
      );
    }
    return Text(message.text, style: Theme.of(context).textTheme.bodyMedium);
  }

  int _toInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Color _severityColor(BuildContext context, String key, bool isPhq9) {
    switch (key) {
      case 'minimal':
        return Colors.green;
      case 'mild':
        return Colors.lightGreen;
      case 'moderate':
        return Colors.orange;
      case 'moderately_severe':
        return isPhq9 ? Colors.deepOrange : Colors.red;
      case 'severe':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _severityEn(String key, bool isPhq9) {
    switch (key) {
      case 'minimal':
        return 'Minimal';
      case 'mild':
        return 'Mild';
      case 'moderate':
        return 'Moderate';
      case 'moderately_severe':
        return isPhq9 ? 'Moderately severe' : 'Severe';
      case 'severe':
        return 'Severe';
      default:
        return key.isEmpty ? '-' : key;
    }
  }

  String _fmt(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  Widget _buildHistoryMiniChart(BuildContext context, Map meta, int maxScore) {
    final hist = meta['history'];
    if (hist is! List || hist.isEmpty) return const SizedBox.shrink();
    
    // 只显示当前量表的历史记录（通过 scale 字段过滤）
    final currentScale = meta['scale']?.toString() ?? '';
    final filteredHist = hist.where((e) => e is Map && (e['scale']?.toString() ?? '') == currentScale).toList();
    
    if (filteredHist.isEmpty) return const SizedBox.shrink();
    
    final points = <_Point>[];
    for (final e in filteredHist) {
      if (e is Map) {
        final t = DateTime.tryParse((e['at'] ?? '').toString()) ?? DateTime.now();
        final s = _toInt(e['score']);
        points.add(_Point(t, s));
      }
    }
    if (points.length < 2) return const SizedBox.shrink();
    points.sort((a, b) => a.t.compareTo(b.t));
    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _SparklinePainter(points, maxScore, Theme.of(context).colorScheme.primary),
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_shortDate(points.first.t), style: Theme.of(context).textTheme.bodySmall),
              Text(_shortDate(points.last.t), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime d) => '${d.month}/${d.day}';

}

class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(top: 6, bottom: 2, right: 64),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
          ),
          child: Row(children: const [
            _Dot(), SizedBox(width: 4), _Dot(), SizedBox(width: 4), _Dot(),
          ]),
        ),
      ],
    );
  }
}

class _Point {
  _Point(this.t, this.y);
  final DateTime t;
  final int y;
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points, this.maxScore, this.color);
  final List<_Point> points;
  final int maxScore;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true;

    final path = Path();
    final n = points.length;
    final dx = size.width / (n - 1);
    for (int i = 0; i < n; i++) {
      final x = dx * i;
      final y = size.height - (points[i].y.clamp(0, maxScore) / maxScore) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // 画节点
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final x = dx * i;
      final y = size.height - (points[i].y.clamp(0, maxScore) / maxScore) * size.height;
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxScore != maxScore || oldDelegate.color != color;
  }
}

class _Dot extends StatefulWidget {
  const _Dot();
  @override
  State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.2, end: 1.0).animate(_c),
      child: const CircleAvatar(radius: 3),
    );
  }
}
