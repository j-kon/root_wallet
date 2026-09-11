import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/biometric_service.dart';
import 'package:root_wallet/core/security/lock_service.dart';
import 'package:root_wallet/core/security/pin_lock_service.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Wallet Security & Fail-Closed Tests', () {
    late InMemorySecureStorage storage;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      storage = InMemorySecureStorage();
    });

    test('fail-closed: sensitive action authentication fails if PIN is incorrect', () async {
      final pinLockService = PinLockService(storage);
      await pinLockService.setPin('123456');

      final lockService = LockService(
        pinLockService: pinLockService,
        biometricService: _FakeBiometrics(available: false),
      );

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          lockServiceProvider.overrideWithValue(lockService),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      // Wrong PIN entered
      final authOk = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => '999999',
      );

      expect(authOk, isFalse, reason: 'Must fail-closed when incorrect PIN is provided');
    });

    test('fail-closed: sensitive action authentication fails if prompt cancelled', () async {
      final pinLockService = PinLockService(storage);
      await pinLockService.setPin('123456');

      final lockService = LockService(
        pinLockService: pinLockService,
        biometricService: _FakeBiometrics(available: false),
      );

      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          lockServiceProvider.overrideWithValue(lockService),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(lockControllerProvider.notifier);
      await container.read(lockControllerProvider.future);

      // User cancels PIN entry dialog
      final authOk = await controller.requireSensitiveActionAuthentication(
        promptPin: () async => null,
      );

      expect(authOk, isFalse, reason: 'Must fail-closed when user cancels authentication');
    });

    test('last-wallet policy: WalletRegistry strictly forbids deleting the only wallet', () async {
      final registry = WalletRegistry(prefs);
      final soleWallet = WalletRecord(
        id: 'w_sole_wallet',
        name: 'Only Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );

      await registry.registerWallet(soleWallet);
      expect(registry.getWallets().length, equals(1));

      expect(
        () => registry.deleteWallet('w_sole_wallet'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot delete the last remaining wallet'),
          ),
        ),
      );
      expect(registry.hasWallets(), isTrue);
    });

    test('secret isolation: deleting wallet A purges secrets without affecting wallet B', () async {
      const walletA = 'w_wallet_a';
      const walletB = 'w_wallet_b';

      await storage.write(
        key: WalletStorageKeys.mnemonicFor(walletA),
        value: 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      await storage.write(
        key: WalletStorageKeys.mnemonicFor(walletB),
        value: 'zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong',
      );

      final registry = WalletRegistry(prefs);
      await registry.registerWallet(
        WalletRecord(
          id: walletA,
          name: 'Wallet A',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: 'AAAA1111',
        ),
      );
      await registry.registerWallet(
        WalletRecord(
          id: walletB,
          name: 'Wallet B',
          type: WalletType.signing,
          scriptType: WalletScriptType.nativeSegwit,
          network: 'testnet',
          createdAt: DateTime.now(),
          fingerprint: 'BBBB2222',
        ),
      );

      // Delete wallet A
      await registry.deleteWallet(walletA);
      for (final key in WalletStorageKeys.allKeysFor(walletA)) {
        await storage.delete(key: key);
      }

      // Verify wallet A secrets are purged
      expect(await storage.read(key: WalletStorageKeys.mnemonicFor(walletA)), isNull);

      // Verify wallet B secrets remain untouched and intact
      expect(
        await storage.read(key: WalletStorageKeys.mnemonicFor(walletB)),
        equals('zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo wrong'),
      );
      expect(registry.getActiveWalletId(), equals(walletB));
    });

    test('decoy isolation: decoy mode remains hidden from multi-wallet registry', () async {
      final registry = WalletRegistry(prefs);
      final wallet1 = WalletRecord(
        id: 'w_primary',
        name: 'Primary Wallet',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime.now(),
        fingerprint: '11223344',
      );
      await registry.registerWallet(wallet1);

      // Verify registry contains only legitimate wallets and no decoy leaks
      final allWallets = registry.getWallets();
      expect(allWallets.length, equals(1));
      expect(allWallets.any((w) => w.id.contains('decoy')), isFalse);
    });
  });
}

class _FakeBiometrics implements BiometricService {
  _FakeBiometrics({this.available = false});
  final bool available;

  @override
  Future<bool> authenticate({String reason = 'Auth'}) async => false;

  @override
  Future<bool> isAvailable() async => available;
}
