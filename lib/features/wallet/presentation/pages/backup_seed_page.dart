import 'package:flutter/material.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/shared/widgets/copy_row.dart';

class BackupSeedPage extends StatelessWidget {
  const BackupSeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    const seed =
        'abandon amount liar amount expire adjust cage candy arch gather drum buyer';

    return AppScaffold(
      title: 'Backup Seed',
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Store this recovery phrase offline. Never share it online.'),
            SizedBox(height: 16),
            CopyRow(value: seed, label: 'Recovery phrase'),
          ],
        ),
      ),
    );
  }
}
