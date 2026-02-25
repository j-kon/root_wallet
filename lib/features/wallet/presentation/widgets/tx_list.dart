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
      return const EmptyState(message: 'No transactions yet');
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => TxTile(item: items[index]),
    );
  }
}
