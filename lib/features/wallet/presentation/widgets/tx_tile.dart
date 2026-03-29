import 'package:flutter/material.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/shared/widgets/transaction_tile.dart';

class TxTile extends StatelessWidget {
  const TxTile({
    super.key,
    required this.item,
    this.onTap,
    this.obscureAmount = false,
  });

  final TxItem item;
  final VoidCallback? onTap;
  final bool obscureAmount;

  @override
  Widget build(BuildContext context) {
    return TransactionTile(
      txId: item.txId,
      amountSats: item.amountSats,
      timestamp: item.timestamp,
      isIncoming: item.isIncoming,
      isPending: item.isPending,
      obscureAmount: obscureAmount,
      onTap: onTap,
    );
  }
}
