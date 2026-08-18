import 'package:flutter/material.dart';

/// Shared network image widget that provides a lightweight skeleton while the
/// image is loading and handles errors gracefully. Centralising this logic
/// keeps the sections tidy and makes it easy to adjust the loading UI later.
class MindWellNetworkImage extends StatelessWidget {
  const MindWellNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderColor,
  });

  final String url;
  final BoxFit fit;
  final Color? placeholderColor;

  @override
  Widget build(BuildContext context) {
    final fallbackColor = placeholderColor ?? Colors.grey.shade300;

    return ClipRect(
      child: Image.network(
        url,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          final expected = progress.expectedTotalBytes;
          final value = expected != null
              ? progress.cumulativeBytesLoaded / expected
              : null;

          return Container(
            color: fallbackColor,
            alignment: Alignment.center,
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(value: value, strokeWidth: 2.6),
            ),
          );
        },
        errorBuilder: (context, _, __) => Container(
          color: fallbackColor,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}
