import 'package:flutter/material.dart';

/// A scaffold helper tuned for the MindWell web experience.
///
/// It centres page content with a max-width constraint so layouts look great on
/// large screens while still collapsing sensibly on tablets and phones.
class MindWellResponsiveScaffold extends StatelessWidget {
  const MindWellResponsiveScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.maxContentWidth = 1180,
    this.scrollable = true,
    this.padding,
    this.useSafeArea = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Widget child;
  final Color? backgroundColor;
  final double maxContentWidth;
  final bool scrollable;
  final EdgeInsetsGeometry? padding;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final scaffoldBg =
        backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    final page = LayoutBuilder(
      builder: (context, constraints) {
        final paddingValue =
            padding ?? _responsivePadding(constraints.maxWidth);
        Widget content = Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(padding: paddingValue, child: child),
          ),
        );
        if (scrollable) {
          content = SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: content,
            ),
          );
        }
        if (useSafeArea) {
          content = SafeArea(top: false, child: content);
        }
        return content;
      },
    );

    return Scaffold(
      appBar: appBar,
      backgroundColor: scaffoldBg,
      body: page,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }

  EdgeInsetsGeometry _responsivePadding(double width) {
    if (width <= 480) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 20);
    }
    if (width <= 960) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 28);
    }
    return const EdgeInsets.symmetric(horizontal: 40, vertical: 36);
  }
}
