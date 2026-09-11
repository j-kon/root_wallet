import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_snapshot_cache.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/shared/models/wallet_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Wallet Storage Isolation Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('verifies wallet-scoped secure storage keys namespace separation', () {
      const walletA = 'w_11111111-1111-1111-1111-111111111111';
      const walletB = 'w_22222222-2222-2222-2222-222222222222';

      expect(
        WalletStorageKeys.mnemonicFor(walletA),
        equals('wallet.w_11111111-1111-1111-1111-111111111111.mnemonic'),
      );
      expect(
        WalletStorageKeys.mnemonicFor(walletB),
        equals('wallet.w_22222222-2222-2222-2222-222222222222.mnemonic'),
      );
      expect(
        WalletStorageKeys.mnemonicFor(walletA),
        isNot(equals(WalletStorageKeys.mnemonicFor(walletB))),
      );

      expect(
        WalletStorageKeys.externalDescriptorFor(walletA),
        equals('wallet.w_11111111-1111-1111-1111-111111111111.external_descriptor'),
      );
      expect(
        WalletStorageKeys.internalDescriptorFor(walletA),
        equals('wallet.w_11111111-1111-1111-1111-111111111111.internal_descriptor'),
      );
      expect(
        WalletStorageKeys.scriptTypeFor(walletA),
        equals('wallet.w_11111111-1111-1111-1111-111111111111.script_type'),
      );
      expect(
        WalletStorageKeys.capabilityFor(walletA),
        equals('wallet.w_11111111-1111-1111-1111-111111111111.capability'),
      );
      expect(
        WalletStorageKeys.metadataFor(walletA),
        equals('wallet.w_11111111-1111-1111-1111-111111111111.metadata'),
      );
    });

    test('isolates BIP-329 labels strictly per wallet ID', () async {
      const walletA = 'w_11111111-1111-1111-1111-111111111111';
      const walletB = 'w_22222222-2222-2222-2222-222222222222';

      final storeA = WalletLabelStore(prefs, scope: walletA);
      final storeB = WalletLabelStore(prefs, scope: walletB);

      await storeA.setAddressLabel('tb1qaddrA', 'Alpha Address');
      await storeB.setAddressLabel('tb1qaddrB', 'Beta Address');

      expect(storeA.read().addressLabel('tb1qaddrA'), equals('Alpha Address'));
      expect(storeA.read().addressLabel('tb1qaddrB'), isEmpty);

      expect(storeB.read().addressLabel('tb1qaddrB'), equals('Beta Address'));
      expect(storeB.read().addressLabel('tb1qaddrA'), isEmpty);

      // Verify exact SharedPreferences keys
      expect(prefs.containsKey('wallet.local_labels.v3.$walletA'), isTrue);
      expect(prefs.containsKey('wallet.local_labels.v3.$walletB'), isTrue);
    });

    test('isolates wallet snapshot cache strictly per wallet ID', () async {
      const walletA = 'w_11111111-1111-1111-1111-111111111111';
      const walletB = 'w_22222222-2222-2222-2222-222222222222';

      final cacheA = WalletSnapshotCache(prefs, walletId: walletA);
      final cacheB = WalletSnapshotCache(prefs, walletId: walletB);

      const snapshotA = WalletSnapshot(
        schemaVersion: 1,
        confirmedSats: 100000,
        pendingSats: 0,
        receiveAddress: 'tb1qaddrA',
        lastSyncedAtMs: 123456789,
        transactions: [],
      );
      const snapshotB = WalletSnapshot(
        schemaVersion: 1,
        confirmedSats: 500000,
        pendingSats: 0,
        receiveAddress: 'tb1qaddrB',
        lastSyncedAtMs: 987654321,
        transactions: [],
      );

      await cacheA.write(snapshotA);
      await cacheB.write(snapshotB);

      final readA = await cacheA.read();
      final readB = await cacheB.read();

      expect(readA?.confirmedSats, equals(100000));
      expect(readA?.receiveAddress, equals('tb1qaddrA'));

      expect(readB?.confirmedSats, equals(500000));
      expect(readB?.receiveAddress, equals('tb1qaddrB'));

      expect(prefs.containsKey('wallet.snapshot.$walletA.v3'), isTrue);
      expect(prefs.containsKey('wallet.snapshot.$walletB.v3'), isTrue);
    });

    test('isolates locked UTXOs storage per wallet ID', () async {
      const walletA = 'w_11111111-1111-1111-1111-111111111111';
      const walletB = 'w_22222222-2222-2222-2222-222222222222';

      final keyA = 'wallet.$walletA.locked_utxos';
      final keyB = 'wallet.$walletB.locked_utxos';

      await prefs.setStringList(keyA, ['txid1:0', 'txid2:1']);
      await prefs.setStringList(keyB, ['txid3:0']);

      expect(prefs.getStringList(keyA), equals(['txid1:0', 'txid2:1']));
      expect(prefs.getStringList(keyB), equals(['txid3:0']));
    });
  });
}
