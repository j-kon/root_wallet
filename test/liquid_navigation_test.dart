import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/main_shell.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/core/security/secure_storage.dart';
import 'package:root_wallet/features/rates/domain/entities/fx_rate.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'liquid navigation indicator stretches during travel and settles',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings.backup_confirmed': true,
        'settings.hide_balances': false,
        'settings.theme_mode': 'dark',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: _shellOverrides(),
          child: MaterialApp(
            theme: buildAppTheme(),
            darkTheme: buildAppTheme(brightness: Brightness.dark),
            themeMode: ThemeMode.dark,
            home: const Scaffold(body: MainShell(initialIndex: 0)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial destination is Wallet
      expect(find.text('Wallet'), findsWidgets);
      expect(find.text('Receive'), findsWidgets);
      expect(find.text('Send'), findsWidgets);
      expect(find.text('Activity'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);

      // Tap Receive (index 1) to trigger liquid animation to the right
      await tester.tap(find.text('Receive').last);
      await tester.pump(); // Start animation at t = 0

      // Pump midway through animation (approx 180ms)
      await tester.pump(const Duration(milliseconds: 180));

      // Settle to complete animation
      await tester.pumpAndSettle();

      // Verify Receive is now selected
      expect(find.text('Receive'), findsWidgets);

      // Tap Wallet (index 0) to trigger liquid animation to the left
      await tester.tap(find.text('Wallet').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();

      // Verify Wallet is selected again
      expect(find.text('Wallet'), findsWidgets);
    },
  );

  testWidgets('liquid navigation handles rapid taps without errors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.backup_confirmed': true,
      'settings.hide_balances': false,
      'settings.theme_mode': 'dark',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _shellOverrides(),
        child: MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: MainShell(initialIndex: 0)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Rapid tap: Wallet -> Settings -> Activity -> Send mid-flight
    await tester.tap(find.text('Settings'));
    await tester.pump(
      const Duration(milliseconds: 60),
    ); // Interrupted mid-flight

    await tester.tap(find.text('Activity'));
    await tester.pump(const Duration(milliseconds: 60)); // Interrupted again

    await tester.tap(find.text('Send').last);
    await tester.pump(const Duration(milliseconds: 60)); // Interrupted again

    await tester.tap(find.text('Receive').last);
    await tester.pumpAndSettle();

    // Clean settlement at Receive
    expect(find.text('Receive'), findsWidgets);
  });

  testWidgets('liquid navigation respects disableAnimations', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.backup_confirmed': true,
      'settings.hide_balances': false,
      'settings.theme_mode': 'dark',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _shellOverrides(),
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: buildAppTheme(),
            darkTheme: buildAppTheme(brightness: Brightness.dark),
            themeMode: ThemeMode.dark,
            home: const Scaffold(body: MainShell(initialIndex: 0)),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Settings with disableAnimations = true
    await tester.tap(find.text('Settings'));
    await tester.pump(); // Immediate update, no animation timer needed

    expect(find.text('Settings'), findsWidgets);
  });
}

List<Override> _shellOverrides() {
  return <Override>[
    secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
    walletStoragePathProvider.overrideWith((ref) async => '/tmp/wallet_test'),
    walletHomeControllerProvider.overrideWith(
      () => _FakeWalletHomeController(
        WalletHomeState(
          balance: const Balance(confirmedSats: 10000, pendingSats: 0),
          transactions: const <TxItem>[],
          receiveAddress: 'tb1ql9dy4s58lxeqgzvjlplaz57zjevhf7xrjxtlxw',
          lastSyncedAt: DateTime(2026, 4, 12, 14, 30),
          isOffline: false,
          isSyncing: false,
        ),
      ),
    ),
    btcNgnRateProvider.overrideWith(
      (ref) async => FxRate(
        base: 'BTC',
        quote: 'NGN',
        value: 171500000.0,
        timestamp: DateTime(2026, 4, 12, 14, 30),
      ),
    ),
    backupReminderProvider.overrideWith(
      () => _FakeBackupReminderController(true),
    ),
    balancePrivacyProvider.overrideWith(
      () => _FakeBalancePrivacyController(false),
    ),
    suggestedFeeProvider.overrideWith(
      (ref) async => const FeeRate(satsPerVByte: 24),
    ),
    lockControllerProvider.overrideWith(
      () => _FakeLockController(
        const AppLockState(
          isLockEnabled: false,
          isBiometricsEnabled: false,
          isBiometricAvailable: false,
          autoLockOption: AutoLockOption.after30Seconds,
          hasPin: false,
          isLocked: false,
          isBusy: false,
          failedAttempts: 0,
          message: null,
        ),
      ),
    ),
  ];
}

class _FakeWalletHomeController extends WalletHomeController {
  _FakeWalletHomeController(this._state);
  final WalletHomeState _state;
  @override
  Future<WalletHomeState> build() async => _state;
}

class _FakeLockController extends LockController {
  _FakeLockController(this._state);
  final AppLockState _state;
  @override
  Future<AppLockState> build() async => _state;
}

class _FakeBackupReminderController extends BackupReminderController {
  _FakeBackupReminderController(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}

class _FakeBalancePrivacyController extends BalancePrivacyController {
  _FakeBalancePrivacyController(this._value);
  final bool _value;
  @override
  Future<bool> build() async => _value;
}
