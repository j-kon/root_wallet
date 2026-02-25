import 'package:flutter/material.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';

class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.item});

  final TxItem item;

  @override
  Widget build(BuildContext context) {
    final icon = item.isIncoming ? Icons.call_received : Icons.call_made;
    final amountPrefix = item.isIncoming ? '+' : '-';

    return ListTile(
      leading: Icon(icon),
      title: Text(item.txId),
      subtitle: Text(AppDateTime.ymdHm(item.timestamp)),
      trailing: Text('$amountPrefix${item.amountSats} sats'),
    );
  }
}
