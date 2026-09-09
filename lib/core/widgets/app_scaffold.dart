import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/colors.dart';

/// Clean, solid application scaffold for Root Wallet.
///
/// Strictly uses flat brand fills from the official color system.
/// All glowing orbs and gradient decorations have been retired.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.titleWidget,
    this.actions,
    this.floatingActionButton,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final background = isDark
        ? RootBrandColors.charcoalPine
        : RootBrandColors.warmIvory;

    return Scaffold(
      backgroundColor: background,
      extendBody: true,
      appBar: (title == null && titleWidget == null)
          ? null
          : AppBar(
              title: titleWidget ?? (title != null ? Text(title!) : null),
              actions: actions,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      body: SafeArea(top: true, bottom: false, child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}
