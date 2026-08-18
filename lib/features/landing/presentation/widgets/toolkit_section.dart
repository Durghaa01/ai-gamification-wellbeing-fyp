import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/design_system/components/section_container.dart';
import 'package:flutter_application_mhproj/design_system/tokens/color_tokens.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';

class MindWellToolkitFeature {
  const MindWellToolkitFeature({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
}

class MindWellToolkitSection extends StatelessWidget {
  const MindWellToolkitSection({super.key, required this.features});

  final List<MindWellToolkitFeature> features;

  @override
  Widget build(BuildContext context) {
    return MindWellSection(
      backgroundColor: Colors.grey.shade100,
      child: Column(
        children: [
          Text(
            'Your MindWell Toolkit',
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
              if (width >= 1120) {
                crossAxisCount = 3;
              } else if (width >= 760) {
                crossAxisCount = 2;
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 1,
                ),
                itemCount: features.length,
                itemBuilder: (context, index) {
                  final feature = features[index];
                  return _ToolkitCard(feature: feature);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToolkitCard extends StatelessWidget {
  const _ToolkitCard({required this.feature});

  final MindWellToolkitFeature feature;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black.withOpacity(0.06),
      child: InkWell(
        onTap: feature.onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(feature.icon, color: MindWellColors.lightGreen, size: 48),
              const SizedBox(height: 20),
              Text(
                feature.title,
                textAlign: TextAlign.center,
                style: MindWellTypography.cardTitle(
                  color: MindWellColors.darkGray,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                feature.description,
                textAlign: TextAlign.center,
                style: MindWellTypography.body(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
