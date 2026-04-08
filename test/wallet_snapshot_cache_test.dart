import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_snapshot_cache.dart';
import 'package:root_wallet/shared/models/wallet_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('WalletSnapshotCache', () {
    test('reads legacy cache payloads without schemaVersion', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallet.snapshot.v1': jsonEncode(<String, Object>{
          'confirmedSats': 1000,
          'pendingSats': 25,
          'receiveAddress': 'tb1qlegacyaddress',
          'lastSyncedAtMs': 1700000000000,
          'transactions': <Object>[],
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final cache = WalletSnapshotCache(prefs);

      final snapshot = await cache.read();

      expect(snapshot, isNotNull);
      expect(snapshot?.schemaVersion, AppConstants.walletSnapshotSchemaVersion);
      expect(snapshot?.receiveAddress, 'tb1qlegacyaddress');
    });

    test('clears unsupported schema snapshots', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallet.snapshot.v2': jsonEncode(<String, Object>{
          'schemaVersion': 999,
          'confirmedSats': 1000,
          'pendingSats': 25,
          'receiveAddress': 'tb1qbadcache',
          'lastSyncedAtMs': 1700000000000,
          'transactions': <Object>[],
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final cache = WalletSnapshotCache(prefs);

      final snapshot = await cache.read();

      expect(snapshot, isNull);
      expect(prefs.getString('wallet.snapshot.v2'), isNull);
    });

    test('writes current version and removes legacy key', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallet.snapshot.v1': 'legacy',
      });
      final prefs = await SharedPreferences.getInstance();
      final cache = WalletSnapshotCache(prefs);

      await cache.write(
        const WalletSnapshot(
          schemaVersion: AppConstants.walletSnapshotSchemaVersion,
          confirmedSats: 2000,
          pendingSats: 50,
          receiveAddress: 'tb1qfreshcache',
          lastSyncedAtMs: 1700000000000,
          transactions: <WalletSnapshotTx>[],
        ),
      );

      expect(prefs.getString('wallet.snapshot.v1'), isNull);
      expect(prefs.getString('wallet.snapshot.v2'), isNotNull);
    });
  });
}
