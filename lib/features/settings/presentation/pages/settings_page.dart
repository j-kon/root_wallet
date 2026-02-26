import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final useCupertino = platform == TargetPlatform.iOS;

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              useCupertino ? CupertinoIcons.add_circled : Icons.add_circle_outline,
            ),
            title: const Text('Create wallet'),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.createWallet),
          ),
          ListTile(
            leading: Icon(
              useCupertino
                  ? CupertinoIcons.arrow_2_circlepath
                  : Icons.restore_rounded,
            ),
            title: const Text('Restore wallet'),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.restoreWallet),
          ),
          ListTile(
            leading: Icon(
              useCupertino ? CupertinoIcons.lock_shield : Icons.security,
            ),
            title: const Text('Security'),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.security),
          ),
          ListTile(
            leading: Icon(
              useCupertino
                  ? CupertinoIcons.question_circle
                  : Icons.help_outline_rounded,
            ),
            title: const Text('Help / Support'),
            onTap: () => _openSupport(context),
          ),
          ListTile(
            leading: Icon(
              useCupertino ? CupertinoIcons.info_circle : Icons.info_outline,
            ),
            title: const Text('About'),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupport(BuildContext context) async {
    final uri = Uri.parse(AppConstants.supportUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) {
      return;
    }

    await Clipboard.setData(const ClipboardData(text: AppConstants.supportUrl));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open browser. Support URL copied.')),
    );
  }
}
