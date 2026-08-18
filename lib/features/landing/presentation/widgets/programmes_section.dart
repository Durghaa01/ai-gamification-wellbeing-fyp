import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/design_system/components/network_image.dart';
import 'package:flutter_application_mhproj/design_system/components/section_container.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';

class MindWellProgramme {
  const MindWellProgramme({
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

class MindWellProgrammesSection extends StatelessWidget {
  const MindWellProgrammesSection({super.key, required this.programmes});

  final List<MindWellProgramme> programmes;

  @override
  Widget build(BuildContext context) {
    return MindWellSection(
      backgroundColor: MindWellColors.cream,
      child: Column(
        children: [
          Text(
            'Our Core Programmes',
            textAlign: TextAlign.center,
            style: MindWellTypography.sectionTitle(
              color: MindWellColors.darkGray,
            ),
          ),
          const SizedBox(height: 48),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              int crossAxisCount = 1;
              if (width >= 1080) {
                crossAxisCount = 3;
              } else if (width >= 720) {
                crossAxisCount = 2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 0.78,
                ),
                itemCount: programmes.length,
                itemBuilder: (context, index) {
                  final programme = programmes[index];
                  return _ProgrammeCard(programme: programme);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({required this.programme});

  final MindWellProgramme programme;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      shadowColor: Colors.black.withOpacity(0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: MindWellNetworkImage(url: programme.imageUrl),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    programme.title,
                    style: MindWellTypography.cardTitle(
                      color: MindWellColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      programme.description,
                      style: MindWellTypography.body(
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: programme.onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MindWellColors.darkGray,
                      foregroundColor: MindWellColors.cream,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      'View Programme'.toUpperCase(),
                      style: MindWellTypography.button(
                        color: MindWellColors.cream,
                      ).copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
