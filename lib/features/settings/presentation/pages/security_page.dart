import 'package:flutter/material.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';

class SecurityPage extends StatelessWidget {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Security',
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Biometric lock'),
            SizedBox(height: 8),
            Text('PIN lock'),
            SizedBox(height: 8),
            Text('Auto-lock timeout'),
          ],
        ),
      ),
    );
  }
}
