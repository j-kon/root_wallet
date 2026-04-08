import 'package:root_wallet/features/rates/data/datasources/rates_remote_datasource.dart';
import 'package:root_wallet/features/rates/domain/entities/fx_rate.dart';
import 'package:root_wallet/features/rates/domain/repositories/rates_repository.dart';

class RatesRepositoryImpl implements RatesRepository {
  RatesRepositoryImpl(this._remoteDatasource);

  final RatesRemoteDatasource _remoteDatasource;

  @override
  Future<FxRate> fetchRate({String base = 'BTC', String quote = 'USD'}) {
    return _remoteDatasource.fetchRate(base: base, quote: quote);
  }
}
