import 'package:flutter/material.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'About',
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppConstants.appName),
            SizedBox(height: 8),
            Text('Feature-based Flutter wallet architecture with Riverpod.'),
          ],
        ),
      ),
    );
  }
}
