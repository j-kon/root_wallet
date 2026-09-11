import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WalletRegistry Tests', () {
    late SharedPreferences prefs;
    late WalletRegistry registry;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      registry = WalletRegistry(prefs);
    });

    test('starts empty and returns null active wallet', () {
      expect(registry.hasWallets(), isFalse);
      expect(registry.getWallets(), isEmpty);
      expect(registry.getActiveWalletId(), isNull);
      expect(registry.getActiveWallet(), isNull);
    });

    const wallet1Id = 'w_11111111-1111-1111-1111-111111111111';
    const wallet2Id = 'w_22222222-2222-2222-2222-222222222222';
    const nonexistentId = 'w_99999999-9999-9999-9999-999999999999';

    test('registers first wallet and automatically makes it active', () async {
      final wallet1 = WalletRecord(
        id: wallet1Id,
        name: 'Main Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );

      await registry.registerWallet(wallet1);

      expect(registry.hasWallets(), isTrue);
      expect(registry.getWallets().length, equals(1));
      expect(registry.getActiveWalletId(), equals(wallet1Id));
      expect(registry.getActiveWallet()?.id, equals(wallet1Id));
      expect(registry.getActiveWallet()?.isActive, isTrue);
    });

    test('registers second wallet without making it active unless specified', () async {
      final wallet1 = WalletRecord(
        id: wallet1Id,
        name: 'Main Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );
      final wallet2 = WalletRecord(
        id: wallet2Id,
        name: 'Second Wallet',
        type: WalletType.watchOnly,
        scriptType: WalletScriptType.taproot,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '55667788',
      );

      await registry.registerWallet(wallet1);
      await registry.registerWallet(wallet2, makeActive: false);

      expect(registry.getWallets().length, equals(2));
      expect(registry.getActiveWalletId(), equals(wallet1Id));

      final list = registry.getWallets();
      expect(list.firstWhere((w) => w.id == wallet1Id).isActive, isTrue);
      expect(list.firstWhere((w) => w.id == wallet2Id).isActive, isFalse);
    });

    test('switches active wallet', () async {
      final wallet1 = WalletRecord(
        id: wallet1Id,
        name: 'Main Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );
      final wallet2 = WalletRecord(
        id: wallet2Id,
        name: 'Second Wallet',
        type: WalletType.watchOnly,
        scriptType: WalletScriptType.taproot,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '55667788',
      );

      await registry.registerWallet(wallet1);
      await registry.registerWallet(wallet2, makeActive: false);

      await registry.setActiveWalletId(wallet2Id);
      expect(registry.getActiveWalletId(), equals(wallet2Id));
      expect(registry.getActiveWallet()?.id, equals(wallet2Id));

      // Attempting to switch to unknown wallet throws
      expect(
        () => registry.setActiveWalletId(nonexistentId),
        throwsA(isA<WalletRegistryException>()),
      );
    });

    test('renames wallet with validation', () async {
      final wallet1 = WalletRecord(
        id: wallet1Id,
        name: 'Old Name',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );

      await registry.registerWallet(wallet1);
      await registry.renameWallet(wallet1Id, 'New Name');

      expect(registry.getWallets().first.name, equals('New Name'));

      // Rejects empty name or too long name
      expect(
        () => registry.renameWallet(wallet1Id, '   '),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => registry.renameWallet(wallet1Id, 'A' * 41),
        throwsA(isA<FormatException>()),
      );
    });

    test('prevents registering duplicate wallet ID', () async {
      final wallet1 = WalletRecord(
        id: wallet1Id,
        name: 'Unique Name',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );
      await registry.registerWallet(wallet1);

      // Duplicate ID
      expect(
        () => registry.registerWallet(wallet1),
        throwsA(isA<WalletRegistryException>()),
      );
    });

    test('finds wallet by fingerprint case-insensitively', () async {
      final wallet = WalletRecord(
        id: wallet1Id,
        name: 'Main Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: 'A1B2C3D4',
      );
      await registry.registerWallet(wallet);

      expect(registry.findByFingerprint('a1b2c3d4')?.id, equals(wallet1Id));
      expect(registry.findByFingerprint('A1B2C3D4')?.id, equals(wallet1Id));
      expect(registry.findByFingerprint('FFFFFFFF'), isNull);
    });

    group('Deletion and Last-Wallet Protection Policy', () {
      test('strictly blocks deleting the last remaining wallet', () async {
        final wallet1 = WalletRecord(
          id: wallet1Id,
          name: 'Sole Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '11223344',
        );
        await registry.registerWallet(wallet1);

        expect(
          () => registry.deleteWallet(wallet1Id),
          throwsA(isA<StateError>()),
        );
        expect(registry.hasWallets(), isTrue);
      });

      test('deleting active wallet deterministically switches to first remaining wallet', () async {
        final wallet1 = WalletRecord(
          id: wallet1Id,
          name: 'First Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '11111111',
        );
        final wallet2 = WalletRecord(
          id: wallet2Id,
          name: 'Second Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '22222222',
        );
        await registry.registerWallet(wallet1);
        await registry.registerWallet(wallet2);

        // Active wallet is wallet1Id
        expect(registry.getActiveWalletId(), equals(wallet1Id));

        // Delete active wallet
        await registry.deleteWallet(wallet1Id);

        expect(registry.getWallets().length, equals(1));
        expect(registry.getActiveWalletId(), equals(wallet2Id));
        expect(registry.getActiveWallet()?.id, equals(wallet2Id));
      });

      test('deleting inactive wallet preserves current active wallet', () async {
        final wallet1 = WalletRecord(
          id: wallet1Id,
          name: 'First Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '11111111',
        );
        final wallet2 = WalletRecord(
          id: wallet2Id,
          name: 'Second Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '22222222',
        );
        await registry.registerWallet(wallet1);
        await registry.registerWallet(wallet2);

        await registry.deleteWallet(wallet2Id);

        expect(registry.getWallets().length, equals(1));
        expect(registry.getActiveWalletId(), equals(wallet1Id));
      });
    });
  });
}
