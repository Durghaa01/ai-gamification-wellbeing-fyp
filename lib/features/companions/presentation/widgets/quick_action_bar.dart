import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

class QuickActionBar extends StatelessWidget {
  factory QuickActionBar({
    required Companion companion,
    required VoidCallback onMoodTap,
    required VoidCallback onPromptTap,
    required VoidCallback onBreathTap,
  }) {
    return QuickActionBar._internal(
      breathingLabel: 'Breathing',
      companion: companion,
      onMoodTap: onMoodTap,
      onPromptTap: onPromptTap,
      onBreathTap: onBreathTap,
    );
  }

  const QuickActionBar._internal({
    required this.breathingLabel,
    required this.companion,
    required this.onMoodTap,
    required this.onPromptTap,
    required this.onBreathTap,
  });

  final String breathingLabel;
  final Companion companion;
  final VoidCallback onMoodTap;
  final VoidCallback onPromptTap;
  final VoidCallback onBreathTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = companion.secondaryColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _QuickActionButton(
              icon: Icons.emoji_emotions_outlined,
              label: 'Mood check',
              color: accent,
              onTap: onMoodTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.auto_awesome_mosaic,
              label: 'Prompt ideas',
              color: companion.primaryColor,
              onTap: onPromptTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionButton(
              icon: Icons.air_outlined,
              label: breathingLabel,
              color: accent,
              onTap: onBreathTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.05),
          ),
          child: Column(
            children: <Widget>[
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
