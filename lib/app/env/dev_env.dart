import 'package:root_wallet/app/env/app_env.dart';

class DevEnv extends AppEnv {
  const DevEnv();

  @override
  Uri get apiBaseUri => Uri.parse('https://api.dev.rootwallet.local');

  @override
  bool get enableLogging => true;

  @override
  String get flavor => 'dev';

  @override
  bool get isProduction => false;
}
