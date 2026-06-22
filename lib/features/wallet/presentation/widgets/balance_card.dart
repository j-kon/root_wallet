import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/widgets/balance_card.dart' as shared;

class BalanceCard extends ConsumerWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.fiatAmountLabel,
    this.subtitle = 'Available balance',
    this.obscureValues = false,
  });

  final Balance balance;
  final String fiatAmountLabel;
  final String subtitle;
  final bool obscureValues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(balanceUnitProvider).valueOrNull ?? BalanceUnit.sats;
    final ngnRate = ref.watch(btcNgnRateProvider).valueOrNull?.value ?? 171500000.0;
    final usdRate = ref.watch(btcUsdRateProvider).valueOrNull?.value ?? 64250.12;
    final eurRate = ref.watch(btcEurRateProvider).valueOrNull?.value ?? 59020.40;

    final btcValue = balance.confirmedSats / 100000000.0;

    final String primaryText;
    final String secondaryText;

    if (obscureValues) {
      primaryText = switch (unit) {
        BalanceUnit.sats => AppFormatters.obscuredSats(),
        BalanceUnit.btc => AppFormatters.obscuredBtc(),
        BalanceUnit.ngn => AppFormatters.obscuredNgn(),
        BalanceUnit.usd => AppFormatters.obscuredUsd(),
        BalanceUnit.eur => AppFormatters.obscuredEur(),
      };
      secondaryText = 'Balances hidden';
    } else {
      switch (unit) {
        case BalanceUnit.sats:
          primaryText = AppFormatters.sats(balance.confirmedSats);
          secondaryText = '≈ ${AppFormatters.btc(btcValue)}';
          break;
        case BalanceUnit.btc:
          primaryText = AppFormatters.btc(btcValue);
          secondaryText = '≈ ${AppFormatters.sats(balance.confirmedSats)}';
          break;
        case BalanceUnit.ngn:
          primaryText = AppFormatters.ngn(btcValue * ngnRate);
          secondaryText = '≈ ${AppFormatters.sats(balance.confirmedSats)}';
          break;
        case BalanceUnit.usd:
          primaryText = AppFormatters.usd(btcValue * usdRate);
          secondaryText = '≈ ${AppFormatters.sats(balance.confirmedSats)}';
          break;
        case BalanceUnit.eur:
          primaryText = AppFormatters.eur(btcValue * eurRate);
          secondaryText = '≈ ${AppFormatters.sats(balance.confirmedSats)}';
          break;
      }
    }

    return shared.BalanceCard(
      subtitle: subtitle,
      btcAmount: primaryText,
      fiatAmountLabel: secondaryText,
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(balanceUnitProvider.notifier).cycle();
      },
    );
  }
}
