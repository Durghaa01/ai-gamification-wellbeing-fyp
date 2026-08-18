import 'package:flutter/material.dart';

class MindWellSection extends StatelessWidget {
  const MindWellSection({
    super.key,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
    required this.child,
  });

  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: child,
        ),
      ),
    );
  }
}
