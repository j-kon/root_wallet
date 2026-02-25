import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/features/rates/data/datasources/rates_remote_datasource.dart';
import 'package:root_wallet/features/rates/data/repositories/rates_repository_impl.dart';
import 'package:root_wallet/features/rates/domain/entities/fx_rate.dart';
import 'package:root_wallet/features/rates/domain/repositories/rates_repository.dart';

final ratesRemoteDatasourceProvider = Provider<RatesRemoteDatasource>(
  (ref) => RatesRemoteDatasource(),
);

final ratesRepositoryProvider = Provider<RatesRepository>(
  (ref) => RatesRepositoryImpl(ref.watch(ratesRemoteDatasourceProvider)),
);

final btcUsdRateProvider = FutureProvider<FxRate>((ref) {
  return ref.watch(ratesRepositoryProvider).fetchRate();
});
