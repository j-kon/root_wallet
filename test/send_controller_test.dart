import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';
import 'package:root_wallet/features/send/domain/entities/send_request.dart';
import 'package:root_wallet/features/send/domain/repositories/send_repository.dart';
import 'package:root_wallet/features/send/domain/usecases/broadcast_tx.dart';
import 'package:root_wallet/features/send/domain/usecases/build_tx.dart';
import 'package:root_wallet/features/send/domain/usecases/sign_tx.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_diagnostics.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_overview.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:root_wallet/features/wallet/domain/usecases/get_balance.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

void main() {
  group('SendController', () {
    test(
      'parses bitcoin payment request input into address and amount',
      () async {
        final sendRepository = _FakeSendRepository();
        final walletRepository = _FakeWalletRepository(
          balance: const Balance(confirmedSats: 500000),
        );
        final container = _buildContainer(
          sendRepository: sendRepository,
          walletRepository: walletRepository,
        );
        addTearDown(container.dispose);

        final notifier = container.read(sendControllerProvider.notifier);
        await container.read(suggestedFeeProvider.future);

        notifier.setAddress('bitcoin:tb1qexampleaddress12345?amount=0.0005');
        final state = container.read(sendControllerProvider);

        expect(state.draft.address, 'tb1qexampleaddress12345');
        expect(state.draft.amountBtcText, '0.0005');
      },
    );

    test('blocks review for mainnet addresses', () async {
      final sendRepository = _FakeSendRepository();
      final walletRepository = _FakeWalletRepository(
        balance: const Balance(confirmedSats: 500000),
      );
      final container = _buildContainer(
        sendRepository: sendRepository,
        walletRepository: walletRepository,
      );
      addTearDown(container.dispose);

      final notifier = container.read(sendControllerProvider.notifier);
      await container.read(suggestedFeeProvider.future);

      notifier.setAddress('bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh');
      notifier.setAmountBtc('0.0001');

      expect(notifier.validateForReview(), isFalse);
      expect(
        container.read(sendControllerProvider).errorMessage,
        'Mainnet address detected. Use a Bitcoin testnet4 address.',
      );
    });

    test(
      'uses confirmed balance instead of total balance when sending',
      () async {
        final sendRepository = _FakeSendRepository();
        final walletRepository = _FakeWalletRepository(
          balance: const Balance(confirmedSats: 1000, pendingSats: 200000),
        );
        final container = _buildContainer(
          sendRepository: sendRepository,
          walletRepository: walletRepository,
        );
        addTearDown(container.dispose);

        final notifier = container.read(sendControllerProvider.notifier);
        await container.read(suggestedFeeProvider.future);

        notifier.setAddress('tb1qexampleaddress12345');
        notifier.setAmountBtc('0.00001');

        final txId = await notifier.send();

        expect(txId, isNull);
        expect(
          container.read(sendControllerProvider).errorMessage,
          'Insufficient balance.',
        );
        expect(sendRepository.buildRequests, isEmpty);
      },
    );
  });
}

ProviderContainer _buildContainer({
  required _FakeSendRepository sendRepository,
  required _FakeWalletRepository walletRepository,
}) {
  return ProviderContainer(
    overrides: [
      buildTxUsecaseProvider.overrideWithValue(BuildTx(sendRepository)),
      signTxUsecaseProvider.overrideWithValue(SignTx(sendRepository)),
      broadcastTxUsecaseProvider.overrideWithValue(BroadcastTx(sendRepository)),
      getBalanceUsecaseProvider.overrideWithValue(GetBalance(walletRepository)),
      suggestedFeeProvider.overrideWith(
        (ref) async => const FeeRate(satsPerVByte: 1),
      ),
    ],
  );
}

class _FakeSendRepository implements SendRepository {
  final List<SendRequest> buildRequests = <SendRequest>[];

  @override
  Future<String> broadcastTx(String signedTx) async => 'txid';

  @override
  Future<String> buildTx(SendRequest request) async {
    buildRequests.add(request);
    return 'psbt';
  }

  @override
  Future<String> signTx(String psbt) async => 'signed_tx';
}

class _FakeWalletRepository implements WalletRepository {
  _FakeWalletRepository({required this.balance});

  final Balance balance;

  @override
  Future<WalletIdentity> createWallet() {
    throw UnimplementedError();
  }

  @override
  Future<String> getAddress() {
    throw UnimplementedError();
  }

  @override
  Future<Balance> getBalance() async => balance;

  @override
  Future<WalletDiagnostics> getDiagnostics() {
    throw UnimplementedError();
  }

  @override
  Future<String> getRecoveryPhrase() {
    throw UnimplementedError();
  }

  @override
  Future<List<TxItem>> getTransactions() async => const <TxItem>[];

  @override
  Future<WalletOverview> getOverview() async {
    return WalletOverview(
      balance: balance,
      transactions: const <TxItem>[],
      receiveAddress: 'tb1qexampleaddress',
    );
  }

  @override
  Future<bool> hasWallet() async => true;

  @override
  Future<WalletIdentity> restoreWallet({required String mnemonic}) {
    throw UnimplementedError();
  }

  @override
  Future<void> rotateBackend() {
    throw UnimplementedError();
  }
}
