import 'package:flutter/material.dart';
import 'package:flutter_application_mhproj/models/companion.dart';

class StickerRail extends StatelessWidget {
  const StickerRail({
    super.key,
    required this.stickers,
    required this.companion,
  });

  final List<String> stickers;
  final Companion companion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: companion.secondaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: stickers.take(6).map((label) {
          return Chip(
            avatar: Icon(
              Icons.stars_rounded,
              size: 18,
              color: companion.primaryColor,
            ),
            label: Text(label),
            backgroundColor: companion.primaryColor.withValues(alpha: 0.08),
            shape: StadiumBorder(
              side: BorderSide(
                color: companion.primaryColor.withValues(alpha: 0.35),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
