import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

class GuestBanner extends StatelessWidget {
  const GuestBanner({
    super.key,
    required this.messageLimit,
    required this.companion,
  });

  final int messageLimit;
  final Companion companion;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.info_outline, color: companion.secondaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Preview mode: up to $messageLimit messages previewed. Sign up to unlock unlimited chat and saved history.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
