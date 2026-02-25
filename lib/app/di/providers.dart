import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/env/app_env.dart';
import 'package:root_wallet/app/env/dev_env.dart';
import 'package:root_wallet/core/logging/logger.dart';
import 'package:root_wallet/core/network/api_client.dart';
import 'package:root_wallet/core/security/secure_storage.dart';

final appEnvProvider = Provider<AppEnv>((ref) => const DevEnv());

final loggerProvider = Provider<AppLogger>((ref) {
  final env = ref.watch(appEnvProvider);
  return ConsoleLogger(enabled: env.enableLogging);
});

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => InMemorySecureStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  final env = ref.watch(appEnvProvider);
  final logger = ref.watch(loggerProvider);
  return ApiClient(baseUri: env.apiBaseUri, logger: logger);
});
