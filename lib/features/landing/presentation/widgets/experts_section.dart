import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/design_system/components/network_image.dart';
import 'package:flutter_application_mhproj/design_system/components/section_container.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';

class MindWellExpertsSection extends StatelessWidget {
  const MindWellExpertsSection({
    super.key,
    required this.imageUrl,
    this.onMeetExperts,
  });

  final String imageUrl;
  final VoidCallback? onMeetExperts;

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
                'Our Team of Experts',
                style: MindWellTypography.sectionTitle(
                  color: MindWellColors.darkGray,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Integrative, Compassionate Care',
                style: MindWellTypography.sectionSubtitle(
                  color: MindWellColors.darkGray,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Our team of world-class psychiatrists, psychologists, neurologists, and wellness experts collaborate to create your truly personalized path to health. We integrate advanced diagnostics with proven therapeutic methods.',
                style: MindWellTypography.body(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: onMeetExperts,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MindWellColors.darkGray,
                  side: const BorderSide(color: MindWellColors.darkGray),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  'Meet Our Experts'.toUpperCase(),
                  style: MindWellTypography.button(
                    color: MindWellColors.darkGray,
                  ).copyWith(fontSize: 12),
                ),
              ),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 4, child: textColumn),
                const SizedBox(width: 40),
                Expanded(flex: 3, child: image),
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
