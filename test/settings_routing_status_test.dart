import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/core/network/network_storage_keys.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/settings/presentation/pages/settings_page.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SettingsPage Connection Routing Row Honesty Tests', () {
    late SharedPreferences prefs;
    late InMemorySecureStorage secureStorage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      secureStorage = InMemorySecureStorage();
    });

    final testWallet = WalletRecord(
      id: 'w_test',
      name: 'Test Wallet',
      type: WalletType.signing,
      scriptType: WalletScriptType.nativeSegwit,
      network: 'testnet',
      createdAt: DateTime(2026, 1, 1),
    );

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          secureStorageProvider.overrideWithValue(secureStorage),
          activeWalletRecordProvider.overrideWithValue(testWallet),
          lockControllerProvider.overrideWith(
            () => _FakeLockController(
              const AppLockState(
                isLockEnabled: false,
                isBiometricsEnabled: false,
                isBiometricAvailable: false,
                autoLockOption: AutoLockOption.immediate,
                hasPin: false,
                isLocked: false,
                isBusy: false,
                failedAttempts: 0,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: SettingsPage()),
        ),
      );
    }

    testWidgets('shows SOCKS5 configuration invalid and Invalid badge when proxyConfig is missing in SOCKS5 mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
      // No host or port

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final routingRow = find.byKey(const ValueKey('settings_connection_routing_row'));
      expect(routingRow, findsOneWidget);

      // Must report invalid configuration honestly
      expect(find.text('SOCKS5 configuration invalid'), findsOneWidget);
      expect(find.text('Invalid'), findsOneWidget);

      // Must NOT imply active or configured
      expect(find.textContaining('Active'), findsNothing);
      expect(find.textContaining('SOCKS5 configured'), findsNothing);
    });

    testWidgets('shows valid SOCKS5 address and SOCKS5 badge when proxy is configured', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await prefs.setString(NetworkStorageKeys.transportMode, 'socks5');
      await prefs.setString(NetworkStorageKeys.proxyHost, '127.0.0.1');
      await prefs.setInt(NetworkStorageKeys.proxyPort, 9050);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final routingRow = find.byKey(const ValueKey('settings_connection_routing_row'));
      expect(routingRow, findsOneWidget);

      expect(find.text('SOCKS5 Proxy (127.0.0.1:9050)'), findsOneWidget);
      expect(find.text('SOCKS5'), findsOneWidget);
    });

    testWidgets('shows Direct testnet connection in direct mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await prefs.setString(NetworkStorageKeys.transportMode, 'direct');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final routingRow = find.byKey(const ValueKey('settings_connection_routing_row'));
      expect(routingRow, findsOneWidget);

      expect(find.text('Direct testnet connection'), findsOneWidget);
      expect(find.text('Direct'), findsOneWidget);
    });
  });
}

class _FakeLockController extends AsyncNotifier<AppLockState> implements LockController {
  _FakeLockController(this._state);
  final AppLockState _state;

  @override
  Future<AppLockState> build() async => _state;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
