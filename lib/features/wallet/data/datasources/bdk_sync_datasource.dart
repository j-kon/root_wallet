import 'package:root_wallet/features/wallet/data/dtos/tx_dto.dart';

class BdkSyncDatasource {
  Future<int> confirmedBalance() async {
    return 1250000;
  }

  Future<int> pendingBalance() async {
    return 60000;
  }

  Future<List<TxDto>> transactions() async {
    final now = DateTime.now();
    return <TxDto>[
      TxDto(
        txId: 'tx_001',
        amountSats: 150000,
        timestamp: now.subtract(const Duration(hours: 6)),
        direction: TxDirection.incoming,
        status: TxStatus.confirmed,
        feeSats: 850,
        confirmations: 6,
      ),
      TxDto(
        txId: 'tx_002',
        amountSats: 32000,
        timestamp: now.subtract(const Duration(days: 1)),
        direction: TxDirection.outgoing,
        status: TxStatus.pending,
        feeSats: 420,
        confirmations: 0,
      ),
    ];
  }
}
