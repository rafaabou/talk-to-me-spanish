import 'package:flutter/material.dart';

class AppSelectionArea extends StatelessWidget {
  final Widget child;
  const AppSelectionArea({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      selectionControls: materialTextSelectionControls,
      magnifierConfiguration: TextMagnifierConfiguration.disabled,
      child: child,
    );
  }
}
