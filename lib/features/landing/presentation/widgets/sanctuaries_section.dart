import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/design_system/components/network_image.dart';
import 'package:flutter_application_mhproj/design_system/components/section_container.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';

class MindWellSanctuary {
  const MindWellSanctuary({
    required this.title,
    required this.description,
    required this.imageUrl,
    this.onPressed,
  });

  final String title;
  final String description;
  final String imageUrl;
  final VoidCallback? onPressed;
}

class MindWellSanctuariesSection extends StatelessWidget {
  const MindWellSanctuariesSection({super.key, required this.sanctuaries});

  final List<MindWellSanctuary> sanctuaries;

  @override
  Widget build(BuildContext context) {
    return MindWellSection(
      backgroundColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Our Sanctuaries',
            textAlign: TextAlign.center,
            style: MindWellTypography.sectionTitle(
              color: MindWellColors.darkGray,
            ),
          ),
          const SizedBox(height: 48),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              int crossAxisCount = 1;
              if (maxWidth >= 1080) {
                crossAxisCount = 3;
              } else if (maxWidth >= 720) {
                crossAxisCount = 2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.8,
                ),
                itemCount: sanctuaries.length,
                itemBuilder: (context, index) {
                  final sanctuary = sanctuaries[index];
                  return _SanctuaryCard(sanctuary: sanctuary);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SanctuaryCard extends StatelessWidget {
  const _SanctuaryCard({required this.sanctuary});

  final MindWellSanctuary sanctuary;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        onTap: sanctuary.onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: MindWellNetworkImage(url: sanctuary.imageUrl),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sanctuary.title,
                      style: MindWellTypography.cardTitle(
                        color: MindWellColors.darkGray,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Text(
                        sanctuary.description,
                        style: MindWellTypography.body(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: sanctuary.onPressed,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MindWellColors.darkGray,
                        side: const BorderSide(color: MindWellColors.darkGray),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: Text(
                        'Discover Location'.toUpperCase(),
                        style: MindWellTypography.button(
                          color: MindWellColors.darkGray,
                        ).copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
