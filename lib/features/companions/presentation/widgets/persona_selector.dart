import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

class PersonaSelector extends StatelessWidget {
  const PersonaSelector({
    super.key,
    required this.presets,
    required this.selected,
    required this.onSelected,
    required this.onInfoTap,
  });

  final List<Companion> presets;
  final Companion selected;
  final ValueChanged<Companion> onSelected;
  final VoidCallback onInfoTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Choose your companion',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              IconButton(
                onPressed: onInfoTap,
                icon: Icon(Icons.info_outline, color: selected.secondaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((companion) {
              final bool isSelected = companion.id == selected.id;
              return ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      companion.icon,
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : theme.iconTheme.color?.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(companion.name),
                  ],
                ),
                selected: isSelected,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.75,
                        ),
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: theme.cardColor,
                selectedColor: companion.primaryColor.withValues(alpha: 0.5),
                side: BorderSide(
                  color: isSelected
                      ? companion.primaryColor.withValues(alpha: 0.8)
                      : theme.dividerColor.withValues(alpha: 0.4),
                ),
                onSelected: (_) => onSelected(companion),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: Text(
              selected.tagline,
              key: ValueKey<String>(selected.id),
              style: MindWellTypography.body(
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8) ??
                    MindWellColors.warmGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
