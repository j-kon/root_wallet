import 'package:root_wallet/app/env/app_env.dart';

class ProdEnv extends AppEnv {
  const ProdEnv();

  @override
  Uri get apiBaseUri => Uri.parse('https://api.rootwallet.app');

  @override
  bool get enableLogging => false;

  @override
  String get flavor => 'prod';

  @override
  bool get isProduction => true;
}
