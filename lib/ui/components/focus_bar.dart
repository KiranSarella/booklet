import 'package:flutter/material.dart';

/// Shared focus treatment for page components and composed layouts.
class FocusBar extends StatelessWidget {
  const FocusBar({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    // Align the bar with the text editor's horizontal margin.
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: child,
    ),
  );
}
