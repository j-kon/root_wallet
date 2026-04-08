import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';

class WalletOverview {
  const WalletOverview({
    required this.balance,
    required this.transactions,
    required this.receiveAddress,
  });

  final Balance balance;
  final List<TxItem> transactions;
  final String receiveAddress;
}
