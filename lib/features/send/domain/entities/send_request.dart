import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';

class SendRequest {
  const SendRequest({
    required this.address,
    required this.amountSats,
    required this.feeRate,
  });

  final String address;
  final int amountSats;
  final FeeRate feeRate;
}
