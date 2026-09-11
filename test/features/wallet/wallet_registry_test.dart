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

    test('registers first wallet and automatically makes it active', () async {
      final wallet1 = WalletRecord(
        id: 'w_wallet_1',
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
      expect(registry.getActiveWalletId(), equals('w_wallet_1'));
      expect(registry.getActiveWallet()?.id, equals('w_wallet_1'));
      expect(registry.getActiveWallet()?.isActive, isTrue);
    });

    test('registers second wallet without making it active unless specified', () async {
      final wallet1 = WalletRecord(
        id: 'w_wallet_1',
        name: 'Main Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );
      final wallet2 = WalletRecord(
        id: 'w_wallet_2',
        name: 'Savings',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '55667788',
      );

      await registry.registerWallet(wallet1);
      await registry.registerWallet(wallet2, makeActive: false);

      expect(registry.getWallets().length, equals(2));
      expect(registry.getActiveWalletId(), equals('w_wallet_1'));

      final list = registry.getWallets();
      expect(list.firstWhere((w) => w.id == 'w_wallet_1').isActive, isTrue);
      expect(list.firstWhere((w) => w.id == 'w_wallet_2').isActive, isFalse);
    });

    test('switches active wallet safely', () async {
      final wallet1 = WalletRecord(
        id: 'w_wallet_1',
        name: 'Main Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );
      final wallet2 = WalletRecord(
        id: 'w_wallet_2',
        name: 'Watch-Only Vault',
        type: WalletType.watchOnly,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '99AABBCC',
      );

      await registry.registerWallet(wallet1);
      await registry.registerWallet(wallet2);

      await registry.setActiveWalletId('w_wallet_2');
      expect(registry.getActiveWalletId(), equals('w_wallet_2'));
      expect(registry.getActiveWallet()?.id, equals('w_wallet_2'));

      // Attempting to switch to unknown wallet throws
      expect(
        () => registry.setActiveWalletId('w_nonexistent'),
        throwsA(isA<WalletRegistryException>()),
      );
    });

    test('renames wallet with validation', () async {
      final wallet1 = WalletRecord(
        id: 'w_wallet_1',
        name: 'Old Name',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );

      await registry.registerWallet(wallet1);
      await registry.renameWallet('w_wallet_1', 'New Name');

      expect(registry.getWallets().first.name, equals('New Name'));

      // Rejects empty name or too long name
      expect(
        () => registry.renameWallet('w_wallet_1', '   '),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => registry.renameWallet('w_wallet_1', 'A' * 41),
        throwsA(isA<FormatException>()),
      );
    });

    test('prevents registering duplicate wallet ID', () async {
      final wallet1 = WalletRecord(
        id: 'w_wallet_1',
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
        id: 'w_wallet_1',
        name: 'Main Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: 'A1B2C3D4',
      );
      await registry.registerWallet(wallet);

      expect(registry.findByFingerprint('a1b2c3d4')?.id, equals('w_wallet_1'));
      expect(registry.findByFingerprint('A1B2C3D4')?.id, equals('w_wallet_1'));
      expect(registry.findByFingerprint('FFFFFFFF'), isNull);
    });

    group('Deletion and Last-Wallet Protection Policy', () {
      test('strictly blocks deleting the last remaining wallet', () async {
        final wallet1 = WalletRecord(
          id: 'w_wallet_1',
          name: 'Sole Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '11223344',
        );
        await registry.registerWallet(wallet1);

        expect(
          () => registry.deleteWallet('w_wallet_1'),
          throwsA(isA<StateError>()),
        );
        expect(registry.hasWallets(), isTrue);
      });

      test('deleting active wallet deterministically switches to first remaining wallet', () async {
        final wallet1 = WalletRecord(
          id: 'w_wallet_1',
          name: 'First Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '11111111',
        );
        final wallet2 = WalletRecord(
          id: 'w_wallet_2',
          name: 'Second Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '22222222',
        );
        await registry.registerWallet(wallet1);
        await registry.registerWallet(wallet2);

        // Active wallet is w_wallet_1
        expect(registry.getActiveWalletId(), equals('w_wallet_1'));

        // Delete active wallet
        await registry.deleteWallet('w_wallet_1');

        expect(registry.getWallets().length, equals(1));
        expect(registry.getActiveWalletId(), equals('w_wallet_2'));
        expect(registry.getActiveWallet()?.id, equals('w_wallet_2'));
      });

      test('deleting inactive wallet preserves current active wallet', () async {
        final wallet1 = WalletRecord(
          id: 'w_wallet_1',
          name: 'First Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '11111111',
        );
        final wallet2 = WalletRecord(
          id: 'w_wallet_2',
          name: 'Second Wallet',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: '22222222',
        );
        await registry.registerWallet(wallet1);
        await registry.registerWallet(wallet2);

        await registry.deleteWallet('w_wallet_2');

        expect(registry.getWallets().length, equals(1));
        expect(registry.getActiveWalletId(), equals('w_wallet_1'));
      });
    });
  });
}
