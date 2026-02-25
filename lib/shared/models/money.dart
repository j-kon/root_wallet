import 'package:root_wallet/core/constants/app_constants.dart';

class Money {
  const Money(this.sats);

  final int sats;

  double get btc => sats / AppConstants.satoshisPerBitcoin;

  String get displayBtc => '${btc.toStringAsFixed(8)} BTC';
  String get displaySats => '$sats sats';
}
