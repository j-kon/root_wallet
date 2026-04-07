import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:root_wallet/app/env/app_env.dart';
import 'package:root_wallet/app/env/dev_env.dart';
import 'package:root_wallet/core/logging/logger.dart';
import 'package:root_wallet/core/network/api_client.dart';
import 'package:root_wallet/core/platform/share_service.dart';
import 'package:root_wallet/core/platform/url_launcher_service.dart';
import 'package:root_wallet/core/security/biometric_service.dart';
import 'package:root_wallet/core/security/lock_service.dart';
import 'package:root_wallet/core/security/pin_lock_service.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appEnvProvider = Provider<AppEnv>((ref) => const DevEnv());

final dateTimeNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final loggerProvider = Provider<AppLogger>((ref) {
  final env = ref.watch(appEnvProvider);
  return ConsoleLogger(enabled: env.enableLogging);
});

final shareServiceProvider = Provider<ShareService>(
  (ref) => const SharePlusService(),
);

final urlLauncherServiceProvider = Provider<UrlLauncherService>(
  (ref) => const UrlLauncherServiceImpl(),
);

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => FlutterSecureStorageAdapter(),
);

final biometricServiceProvider = Provider<BiometricService>(
  (ref) => LocalAuthBiometricService(),
);

final pinLockServiceProvider = Provider<PinLockService>(
  (ref) => PinLockService(ref.watch(secureStorageProvider)),
);

final lockServiceProvider = Provider<LockService>(
  (ref) => LockService(
    pinLockService: ref.watch(pinLockServiceProvider),
    biometricService: ref.watch(biometricServiceProvider),
  ),
);

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return SharedPreferences.getInstance();
});

final walletStoragePathProvider = FutureProvider<String>((ref) async {
  final supportDirectory = await getApplicationSupportDirectory();
  final walletDirectory = Directory('${supportDirectory.path}/wallet');
  if (!await walletDirectory.exists()) {
    await walletDirectory.create(recursive: true);
  }
  return walletDirectory.path;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final env = ref.watch(appEnvProvider);
  final logger = ref.watch(loggerProvider);
  return ApiClient(baseUri: env.apiBaseUri, logger: logger);
});
