import 'package:flutter/material.dart';

import '../theme/dt_theme.dart';
import 'app_drawer.dart';

/// A single, navigation-free application surface. Secondary pages are pushed
/// above it, so the app never reserves screen space for a permanent tab bar.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: dark ? DtColors.darkBg : DtColors.mist,
      drawer: const AppDrawer(),
      body: ColoredBox(
        color: dark ? DtColors.darkBg : DtColors.canvas,
        child: child,
      ),
    );
  }
}
