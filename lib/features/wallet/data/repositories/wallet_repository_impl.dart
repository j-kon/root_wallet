import 'package:root_wallet/features/wallet/data/datasources/bdk_sync_datasource.dart';
import 'package:root_wallet/features/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:root_wallet/features/wallet/data/mappers/tx_mapper.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_identity.dart';
import 'package:root_wallet/features/wallet/domain/repositories/wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl({
    required BdkWalletDatasource walletDatasource,
    required BdkSyncDatasource syncDatasource,
    required TxMapper txMapper,
  }) : _walletDatasource = walletDatasource,
       _syncDatasource = syncDatasource,
       _txMapper = txMapper;

  final BdkWalletDatasource _walletDatasource;
  final BdkSyncDatasource _syncDatasource;
  final TxMapper _txMapper;

  @override
  Future<WalletIdentity> createWallet() {
    return _walletDatasource.createWallet();
  }

  @override
  Future<String> getAddress() {
    return _walletDatasource.getAddress();
  }

  @override
  Future<Balance> getBalance() async {
    final confirmed = await _syncDatasource.confirmedBalance();
    final pending = await _syncDatasource.pendingBalance();
    return Balance(confirmedSats: confirmed, pendingSats: pending);
  }

  @override
  Future<List<TxItem>> getTransactions() async {
    final txs = await _syncDatasource.transactions();
    return txs.map(_txMapper.fromDto).toList(growable: false);
  }

  @override
  Future<WalletIdentity> restoreWallet({required String mnemonic}) {
    return _walletDatasource.restoreWallet(mnemonic: mnemonic);
  }
}
