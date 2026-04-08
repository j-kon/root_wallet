import 'package:root_wallet/features/rates/domain/entities/fx_rate.dart';

abstract class RatesRepository {
  Future<FxRate> fetchRate({String base = 'BTC', String quote = 'USD'});
}
