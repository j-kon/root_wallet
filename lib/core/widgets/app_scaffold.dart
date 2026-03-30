import 'package:flutter/material.dart';
import 'package:root_wallet/app/theme/colors.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  final String? title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final background = AppColors.backgroundOf(context);
    final backgroundTint = AppColors.backgroundTintOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            background,
            backgroundTint,
            background,
          ],
          stops: [0, 0.22, 0.72],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: title == null
            ? null
            : AppBar(title: Text(title!), actions: actions),
        body: SafeArea(child: body),
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}
