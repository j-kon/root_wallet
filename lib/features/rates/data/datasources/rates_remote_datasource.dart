import 'package:root_wallet/features/rates/domain/entities/fx_rate.dart';

class RatesRemoteDatasource {
  Future<FxRate> fetchRate({String base = 'BTC', String quote = 'USD'}) async {
    final normalizedQuote = quote.toUpperCase();
    final value = switch (normalizedQuote) {
      'NGN' => 171500000.0,
      'USD' => 64250.12,
      _ => 1.0,
    };

    return FxRate(
      base: base,
      quote: normalizedQuote,
      value: value,
      timestamp: DateTime.now(),
    );
  }
}
