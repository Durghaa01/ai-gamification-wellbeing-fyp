import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

class QuickActionsCarousel extends StatelessWidget {
  const QuickActionsCarousel({
    super.key,
    required this.companion,
    required this.onPromptSelected,
    required this.onTemplateSelected,
  });

  final Companion companion;
  final ValueChanged<String> onPromptSelected;
  final ValueChanged<String> onTemplateSelected;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[];

    // Add Quick Prompts
    for (final String prompt in companion.quickPrompts) {
      items.add(
        _QuickActionChip(
          label: prompt,
          icon: Icons.lightbulb_outline,
          color: companion.secondaryColor,
          onTap: () => onPromptSelected(prompt),
        ),
      );
    }

    // Add Comfort Templates
    for (final _ComfortTemplate template in _comfortTemplates) {
      items.add(
        _QuickActionChip(
          label: template.label,
          icon: template.icon ?? Icons.favorite_border,
          color: companion.primaryColor,
          onTap: () => onTemplateSelected(template.prompt),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Theme.of(context).cardColor.withValues(alpha: 0.9),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      shape: const StadiumBorder(),
    );
  }
}

class _ComfortTemplate {
  const _ComfortTemplate({
    required this.label,
    required this.prompt,
    this.icon,
  });

  final String label;
  final String prompt;
  final IconData? icon;
}

const List<_ComfortTemplate> _comfortTemplates = <_ComfortTemplate>[
  _ComfortTemplate(
    label: 'Panic',
    prompt: 'I am having a panic attack. Help me ground myself.',
    icon: Icons.warning_amber_rounded,
  ),
  _ComfortTemplate(
    label: 'Can\'t sleep',
    prompt: 'I can\'t sleep and my mind is racing. Help me relax.',
    icon: Icons.bedtime_outlined,
  ),
  _ComfortTemplate(
    label: 'Sad',
    prompt: 'I am feeling really down and lonely right now.',
    icon: Icons.sentiment_dissatisfied,
  ),
  _ComfortTemplate(
    label: 'Anxious',
    prompt: 'I am feeling anxious about something coming up.',
    icon: Icons.psychology_outlined,
  ),
];
