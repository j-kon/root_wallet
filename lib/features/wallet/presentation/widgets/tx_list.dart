import 'package:flutter/material.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/presentation/widgets/tx_tile.dart';

class TxList extends StatelessWidget {
  const TxList({
    super.key,
    required this.items,
    this.onItemTap,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<TxItem> items;
  final ValueChanged<TxItem>? onItemTap;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

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
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemBuilder: (context, index) {
        final item = items[index];
        return TxTile(
          item: item,
          onTap: onItemTap == null ? null : () => onItemTap!(item),
        );
      },
    );
  }
}
