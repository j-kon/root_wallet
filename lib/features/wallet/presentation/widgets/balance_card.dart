import 'package:flutter/material.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/shared/widgets/balance_card.dart' as shared;

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.fiatAmountLabel,
    this.subtitle = 'Available balance',
  });

  final Balance balance;
  final String fiatAmountLabel;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return shared.BalanceCard(
      subtitle: subtitle,
      btcAmount: AppFormatters.btc(balance.btc),
      fiatAmountLabel: fiatAmountLabel,
    );
  }
}
