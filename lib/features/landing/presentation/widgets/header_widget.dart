import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';

class MindWellNavItem {
  const MindWellNavItem({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

class MindWellHeader extends StatelessWidget {
  const MindWellHeader({
    super.key,
    required this.isCompact,
    required this.isMenuOpen,
    required this.onMenuToggle,
    required this.navItems,
    this.onBookPressed,
  });

  final bool isCompact;
  final bool isMenuOpen;
  final VoidCallback onMenuToggle;
  final List<MindWellNavItem> navItems;
  final VoidCallback? onBookPressed;

  @override
  Widget build(BuildContext context) {
    final button = _MindWellButton(
      label: 'Book',
      filled: true,
      onPressed: onBookPressed,
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Text(
                  'MindWell',
                  style: MindWellTypography.sectionSubtitle(
                    color: MindWellColors.darkGray,
                  ).copyWith(letterSpacing: 3, fontSize: 28),
                ),
                const Spacer(),
                if (!isCompact) ...[
                  for (final item in navItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _NavLink(item: item),
                    ),
                  button,
                ] else
                  _MenuButton(onPressed: onMenuToggle),
              ],
            ),
          ),
        ),
        if (isCompact && isMenuOpen)
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final item in navItems)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _NavLink(item: item, alignStart: true),
                  ),
                const SizedBox(height: 12),
                button,
              ],
            ),
          ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.item, this.alignStart = false});

  final MindWellNavItem item;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    final textStyle = MindWellTypography.body(
      color: MindWellColors.darkGray,
    ).copyWith(fontSize: 16, fontWeight: FontWeight.w600);

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(6),
      child: Align(
        alignment: alignStart ? Alignment.centerLeft : Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(item.label, style: textStyle),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(
        Icons.menu_rounded,
        size: 32,
        color: MindWellColors.darkGray,
      ),
      splashRadius: 24,
    );
  }
}

class _MindWellButton extends StatelessWidget {
  const _MindWellButton({
    required this.label,
    required this.filled,
    this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final baseStyle = MindWellTypography.button(
      color: filled ? MindWellColors.cream : MindWellColors.darkGray,
    ).copyWith(fontSize: 12);

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: filled
            ? MindWellColors.cream
            : MindWellColors.darkGray,
        backgroundColor: filled ? MindWellColors.darkGray : Colors.transparent,
        side: const BorderSide(color: MindWellColors.darkGray),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(label.toUpperCase(), style: baseStyle),
    );
  }
}
