import 'package:root_wallet/features/rates/domain/entities/fx_rate.dart';

class RatesRemoteDatasource {
  Future<FxRate> fetchRate({String base = 'BTC', String quote = 'USD'}) async {
    return FxRate(
      base: base,
      quote: quote,
      value: 64250.12,
      timestamp: DateTime.now(),
    );
  }
}
