import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/design_system/components/network_image.dart';
import 'package:flutter_application_mhproj/design_system/tokens/typography.dart';

class MindWellHeroSection extends StatelessWidget {
  const MindWellHeroSection({
    super.key,
    required this.imageUrl,
    this.onExplore,
    this.title,
    this.subtitle,
    this.ctaLabel,
  });

  final String imageUrl;
  final VoidCallback? onExplore;
  final String? title;
  final String? subtitle;
  final String? ctaLabel;

  @override
  Widget build(BuildContext context) {
    final String headline = title ?? 'Clarity. Calm. Connection.';
    final String subHeadline =
        subtitle ?? 'The Future of Mental Wellness is Here.';
    final String primaryCta = (ctaLabel ?? 'Explore Therapies').toUpperCase();

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MindWellNetworkImage(
            url: imageUrl,
            fit: BoxFit.cover,
            placeholderColor: Colors.black26,
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color.fromRGBO(0, 0, 0, 0.65),
                  Color.fromRGBO(0, 0, 0, 0.35),
                  Color.fromRGBO(0, 0, 0, 0.15),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: MindWellTypography.display(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    subHeadline,
                    textAlign: TextAlign.center,
                    style: MindWellTypography.heroSubtitle(),
                  ),
                  const SizedBox(height: 36),
                  OutlinedButton(
                    onPressed: onExplore,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      primaryCta,
                      style: MindWellTypography.button(color: Colors.white),
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
