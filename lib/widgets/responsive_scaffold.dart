import 'package:flutter/material.dart';

class ResponsiveScaffold extends StatelessWidget {
  final Widget mobileLayout;
  final Widget desktopLayout;
  final double breakpoint;

  const ResponsiveScaffold({
    super.key,
    required this.mobileLayout,
    required this.desktopLayout,
    this.breakpoint = 900,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return mobileLayout;
        } else {
          return desktopLayout;
        }
      },
    );
  }
}
