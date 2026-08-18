import 'package:flutter/material.dart';
import '../models/assessment.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});
  final AssessmentMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AgentRole.user;
    final bg = isUser
        ? Theme.of(context).primaryColor.withOpacity(0.12)
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
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.4),
            ),
          ),
          child: Text(
            message.text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Opacity(
            opacity: 0.7,
            child: Text(
              _fmt(message.ts),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
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
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.4),
            ),
          ),
          child: Row(
            children: const [
              _Dot(),
              SizedBox(width: 4),
              _Dot(),
              SizedBox(width: 4),
              _Dot(),
            ],
          ),
        ),
      ],
    );
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
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.2, end: 1.0).animate(_c),
      child: const CircleAvatar(radius: 3),
    );
  }
}
