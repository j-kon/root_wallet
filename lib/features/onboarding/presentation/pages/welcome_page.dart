import 'package:flutter/material.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/primary_button.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Welcome',
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a new wallet or restore an existing recovery phrase.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Create wallet',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.createWallet),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.restoreWallet),
              child: const Text('Restore wallet'),
            ),
          ],
        ),
      ),
    );
  }
}
