import 'package:flutter/material.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Security'),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.security),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.about),
          ),
        ],
      ),
    );
  }
}
