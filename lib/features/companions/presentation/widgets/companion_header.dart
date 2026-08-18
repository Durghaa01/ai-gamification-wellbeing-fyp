import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/features/companions/application/companion_controller.dart';

class CompanionHeader extends StatelessWidget implements PreferredSizeWidget {
  const CompanionHeader({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isGuest,
    required this.onOpenSessionManager,
  });

  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isGuest;
  final VoidCallback onOpenSessionManager;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Companions'),
      actions: <Widget>[
        if (!isGuest)
          IconButton(
            tooltip: 'Manage sessions',
            icon: const Icon(Icons.forum_outlined),
            onPressed: onOpenSessionManager,
          ),
        Switch(value: isDarkMode, onChanged: onThemeChanged),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Text(isDarkMode ? '☾' : '☀'),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
