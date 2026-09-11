import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_registry.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wallet Switcher & Provider Integration Tests', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    final wallet1 = WalletRecord(
      id: 'w_alpha_1',
      name: 'Alpha Wallet',
      type: WalletType.signing,
      scriptType: WalletScriptType.nativeSegwit,
      network: 'testnet',
      createdAt: DateTime.now(),
      fingerprint: '11111111',
    );

    final wallet2 = WalletRecord(
      id: 'w_beta_2',
      name: 'Beta Watch-Only',
      type: WalletType.watchOnly,
      scriptType: WalletScriptType.taproot,
      network: 'testnet',
      createdAt: DateTime.now(),
      fingerprint: '22222222',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      final registry = WalletRegistry(prefs);
      await registry.registerWallet(wallet1, makeActive: true);
      await registry.registerWallet(wallet2, makeActive: false);

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('activeWalletIdProvider loads initial active wallet from registry', () async {
      await container.read(walletsListProvider.future);
      final activeId = await container.read(activeWalletIdProvider.future);
      expect(activeId, equals('w_alpha_1'));

      final activeRecord = container.read(activeWalletRecordProvider);
      expect(activeRecord?.id, equals('w_alpha_1'));
      expect(activeRecord?.name, equals('Alpha Wallet'));
      expect(activeRecord?.type, equals(WalletType.signing));
    });

    test('walletsListProvider marks the active wallet correctly', () async {
      await container.read(activeWalletIdProvider.future);
      final wallets = await container.read(walletsListProvider.future);
      expect(wallets.length, equals(2));

      final first = wallets.firstWhere((w) => w.id == 'w_alpha_1');
      final second = wallets.firstWhere((w) => w.id == 'w_beta_2');

      expect(first.isActive, isTrue);
      expect(second.isActive, isFalse);
    });

    test('switching active wallet updates active record and wallets list', () async {
      await container.read(walletsListProvider.future);
      await container.read(activeWalletIdProvider.future);

      await container
          .read(activeWalletIdProvider.notifier)
          .setActiveWallet('w_beta_2');

      final activeId = await container.read(activeWalletIdProvider.future);
      expect(activeId, equals('w_beta_2'));

      final wallets = await container.read(walletsListProvider.future);
      expect(wallets.firstWhere((w) => w.id == 'w_beta_2').isActive, isTrue);
      expect(wallets.firstWhere((w) => w.id == 'w_alpha_1').isActive, isFalse);

      final activeRecord = container.read(activeWalletRecordProvider);
      expect(activeRecord?.id, equals('w_beta_2'));
      expect(activeRecord?.name, equals('Beta Watch-Only'));
      expect(activeRecord?.isWatchOnly, isTrue);
    });

    test('switching active wallet clears pending send draft state', () async {
      await container.read(activeWalletIdProvider.future);

      // Enter a draft in sendController
      final sendNotifier = container.read(sendControllerProvider.notifier);
      sendNotifier.setAddress('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx');
      sendNotifier.setAmountBtc('0.0005');

      expect(
        container.read(sendControllerProvider).draft.address,
        equals('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx'),
      );
      expect(
        container.read(sendControllerProvider).draft.amountBtcText,
        equals('0.0005'),
      );

      // Switch active wallet
      await container
          .read(activeWalletIdProvider.notifier)
          .setActiveWallet('w_beta_2');

      // Send state must be reset to prevent cross-wallet transfer leaks
      final sendStateAfter = container.read(sendControllerProvider);
      expect(sendStateAfter.draft.address, isEmpty);
      expect(sendStateAfter.draft.amountBtcText, isEmpty);
    });
  });
}
