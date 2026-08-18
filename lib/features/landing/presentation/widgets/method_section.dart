import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/design_system/components/network_image.dart';
import 'package:flutter_application_mhproj/design_system/components/section_container.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';

class MindWellMethodSection extends StatelessWidget {
  const MindWellMethodSection({
    super.key,
    required this.imageUrl,
    this.onLearnMore,
  });

  final String imageUrl;
  final VoidCallback? onLearnMore;

  @override
  Widget build(BuildContext context) {
    return MindWellSection(
      backgroundColor: MindWellColors.cream,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final image = ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: isWide ? 4 / 3 : 16 / 10,
              child: MindWellNetworkImage(url: imageUrl),
            ),
          );

          final textColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The MindWell Method',
                style: MindWellTypography.sectionTitle(
                  color: MindWellColors.darkGray,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'A Holistic Approach to Your Mind',
                style: MindWellTypography.sectionSubtitle(
                  color: MindWellColors.darkGray,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                "The MindWell Method is an integrative approach combining evidence-based psychotherapy, neuroscience, nutritional guidance, and mindfulness practices. It's designed to empower your mind's natural capacity for healing and restore profound balance.",
                style: MindWellTypography.body(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              _MindWellOutlineButton(
                label: 'Learn More About Our Concept',
                onPressed: onLearnMore,
              ),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 3, child: image),
                const SizedBox(width: 40),
                Expanded(flex: 4, child: textColumn),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [image, const SizedBox(height: 32), textColumn],
          );
        },
      ),
    );
  }
}

class _MindWellOutlineButton extends StatelessWidget {
  const _MindWellOutlineButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: MindWellColors.darkGray,
        side: const BorderSide(color: MindWellColors.darkGray),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Text(
        label.toUpperCase(),
        style: MindWellTypography.button(
          color: MindWellColors.darkGray,
        ).copyWith(fontSize: 12),
      ),
    );
  }
}
