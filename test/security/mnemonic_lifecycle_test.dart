import 'package:bdk_dart/bdk_dart.dart' as bdk;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/wallet/data/datasources/wallet_label_store.dart';
import 'package:root_wallet/features/wallet/data/services/wallet_seed_service.dart';
import 'package:root_wallet/features/wallet/data/wallet_storage_keys.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_creation_result.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/shared/models/wallet_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Phase 4: Mnemonic Lifecycle & Exposure Reduction', () {
    late InMemorySecureStorage secureStorage;
    late WalletSeedService seedService;

    setUp(() {
      secureStorage = InMemorySecureStorage();
      seedService = WalletSeedService(
        secureStorage: secureStorage,
        walletStoragePathLoader: () async => '/tmp/root_wallet_test',
      );
    });

    test('WalletIdentity contains only public non-secret metadata', () {
      const identity = WalletIdentity(
        id: 'wallet_testnet_p2wpkh',
        fingerprint: 'A1B2C3D4',
        network: 'testnet',
      );

      expect(identity.id, equals('wallet_testnet_p2wpkh'));
      expect(identity.fingerprint, equals('A1B2C3D4'));
      expect(identity.network, equals('testnet'));
    });

    test('WalletCreationResult holds ephemeral mnemonic and identity', () {
      const identity = WalletIdentity(
        id: 'wallet_testnet_p2wpkh',
        fingerprint: 'A1B2C3D4',
        network: 'testnet',
      );
      const phrase = 'word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12';

      const result = WalletCreationResult(
        walletIdentity: identity,
        recoveryPhrase: phrase,
      );

      expect(result.walletIdentity, equals(identity));
      expect(result.recoveryPhrase, equals(phrase));
    });

    test('WalletSeedService.createWallet returns WalletCreationResult and writes to secure storage only', () async {
      final result = await seedService.createWallet(
        scriptType: WalletScriptType.nativeSegwit,
      );

      expect(result, isA<WalletCreationResult>());
      expect(result.recoveryPhrase.split(' ').length, equals(12));
      expect(result.walletIdentity.network, equals('testnet'));
      expect(result.walletIdentity.fingerprint, isNotEmpty);

      // Verify mnemonic exists in secure storage
      final stored = await secureStorage.read(key: WalletStorageKeys.mnemonic);
      expect(stored, equals(result.recoveryPhrase));
    });

    test('WalletSeedService.restoreWallet returns WalletIdentity without recovery phrase', () async {
      final validMnemonic = bdk.Mnemonic(wordCount: bdk.WordCount.words12).toString();

      final identity = await seedService.restoreWallet(
        mnemonic: validMnemonic,
        scriptType: WalletScriptType.nativeSegwit,
      );

      expect(identity, isA<WalletIdentity>());
      expect(identity.network, equals('testnet'));
      expect(identity.fingerprint, isNotEmpty);

      // Verify stored in secure storage
      final stored = await secureStorage.read(key: WalletStorageKeys.mnemonic);
      expect(stored, equals(validMnemonic));
    });

    test('OnboardingController wipes recoveryPhrase upon backup confirmation', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(secureStorage),
          onboardingWalletSeedServiceProvider.overrideWithValue(seedService),
        ],
      );

      final controller = container.read(onboardingControllerProvider.notifier);

      // Create wallet
      final created = await controller.createWallet();
      expect(created, isTrue);

      final phrase = container.read(onboardingControllerProvider).recoveryPhrase;
      expect(phrase, isNotNull);
      final words = phrase!.split(' ');
      expect(words.length, equals(12));

      // Prepare challenge
      await controller.prepareSeedChallenge();
      final indices = container.read(onboardingControllerProvider).challengeIndices;
      expect(indices, isNotEmpty);

      final answers = <int, String>{
        for (final idx in indices) idx: words[idx - 1],
      };

      // Confirm backup
      final confirmed = await controller.confirmBackup(answers);
      expect(confirmed, isTrue);

      // Mnemonic must be strictly cleared from OnboardingState
      expect(container.read(onboardingControllerProvider).recoveryPhrase, isNull);
    });

    test('Diagnostics JSON export never includes mnemonic or sensitive keys', () {
      const diagnostics = WalletDiagnostics(
        networkLabel: 'Testnet',
        bdkNetwork: 'testnet',
        activeEsploraEndpoint: 'https://mempool.space/testnet/api',
        configuredEsploraEndpoints: ['https://mempool.space/testnet/api'],
        activeEsploraIndex: 0,
        customEsploraEndpoint: null,
        lastBackendFailure: null,
        lastBackendFailureAt: null,
        walletDatabasePath: 'root_wallet_testnet.sqlite',
        walletExists: true,
        scriptType: 'Native SegWit (P2WPKH)',
      );

      final json = diagnostics.toJson();
      final jsonStr = json.toString().toLowerCase();

      expect(jsonStr.contains('mnemonic'), isFalse);
      expect(jsonStr.contains('recoveryphrase'), isFalse);
      expect(jsonStr.contains('seed'), isFalse);
      expect(jsonStr.contains('secret'), isFalse);
      expect(jsonStr.contains('privatekey'), isFalse);
    });

    test('WalletSnapshot and WalletLabelStore serialization never includes mnemonic', () {
      const snapshot = WalletSnapshot(
        schemaVersion: 1,
        confirmedSats: 100000,
        pendingSats: 0,
        receiveAddress: 'tb1qtestaddress',
        lastSyncedAtMs: 1700000000000,
        transactions: [],
      );

      final snapshotJson = snapshot.toJson().toString().toLowerCase();
      expect(snapshotJson.contains('mnemonic'), isFalse);
      expect(snapshotJson.contains('recoveryphrase'), isFalse);

      const labelSnapshot = WalletLabelsSnapshot(
        addressLabels: {'tb1qaddress': 'Savings'},
        transactionMetadata: {},
      );

      final labelsJson = labelSnapshot.toJson().toString().toLowerCase();
      expect(labelsJson.contains('mnemonic'), isFalse);
      expect(labelsJson.contains('recoveryphrase'), isFalse);
    });
  });
}
