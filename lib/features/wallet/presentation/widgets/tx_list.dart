import 'package:flutter/material.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/tx_tile.dart';

class TxList extends StatelessWidget {
  const TxList({super.key, required this.items});

  final List<TxItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        title: 'No activity yet',
        message: 'Receive BTC to see transactions here.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) => TxTile(item: items[index]),
    );
  }
}
