import 'package:root_wallet/core/constants/app_constants.dart';

class Balance {
  const Balance({required this.confirmedSats, this.pendingSats = 0});

  final int confirmedSats;
  final int pendingSats;

  int get totalSats => confirmedSats + pendingSats;

  double get btc => totalSats / AppConstants.satoshisPerBitcoin;
}
