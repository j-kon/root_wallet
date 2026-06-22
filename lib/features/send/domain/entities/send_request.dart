import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';

class SendRequest {
  const SendRequest({
    required this.address,
    required this.amountSats,
    required this.feeRate,
    this.selectedUtxos,
  });

  final String address;
  final int amountSats;
  final FeeRate feeRate;
  final List<String>? selectedUtxos;
}
