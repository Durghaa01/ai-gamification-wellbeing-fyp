import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

class FastlanePersonaCard extends StatelessWidget {
  const FastlanePersonaCard({
    super.key,
    required this.companion,
    required this.onSwitch,
  });

  final Companion companion;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: companion.secondaryColor.withValues(
                  alpha: 0.35,
                ),
                child: Icon(companion.icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Chatting with ${companion.name}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      companion.tagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onSwitch,
                child: const Text('Switch persona'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
