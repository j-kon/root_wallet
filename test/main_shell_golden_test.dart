import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/main_shell.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
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
  final cases = <({String name, int tabIndex, Brightness brightness})>[
    (name: 'wallet_light', tabIndex: 0, brightness: Brightness.light),
    (name: 'receive_light', tabIndex: 1, brightness: Brightness.light),
    (name: 'send_light', tabIndex: 2, brightness: Brightness.light),
    (name: 'settings_light', tabIndex: 3, brightness: Brightness.light),
    (name: 'wallet_dark', tabIndex: 0, brightness: Brightness.dark),
    (name: 'receive_dark', tabIndex: 1, brightness: Brightness.dark),
    (name: 'send_dark', tabIndex: 2, brightness: Brightness.dark),
    (name: 'settings_dark', tabIndex: 3, brightness: Brightness.dark),
  ];

  for (final testCase in cases) {
    testWidgets('main shell golden ${testCase.name}', (tester) async {
      await _pumpShellGolden(
        tester,
        brightness: testCase.brightness,
        initialIndex: testCase.tabIndex,
      );

      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/main_shell_${testCase.name}.png'),
      );
    });
  }
}

const _goldenSurface = Size(390, 844);
const _goldenKey = ValueKey<String>('main-shell-golden');

Future<void> _pumpShellGolden(
  WidgetTester tester, {
  required Brightness brightness,
  required int initialIndex,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'settings.backup_confirmed': true,
    'settings.hide_balances': false,
    'settings.theme_mode': brightness == Brightness.dark ? 'dark' : 'light',
  });

  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _goldenSurface;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: _shellOverrides(),
      child: MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: RepaintBoundary(
          key: _goldenKey,
          child: ExcludeSemantics(child: MainShell(initialIndex: initialIndex)),
        ),
      ),
    ),
  );

  await _stabilizeFrames(tester);
}

Future<void> _stabilizeFrames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

List<Override> _shellOverrides() {
  return <Override>[
    walletHomeControllerProvider.overrideWith(
      () => _FakeWalletHomeController(
        WalletHomeState(
          balance: const Balance(confirmedSats: 139518, pendingSats: 1200),
          transactions: <TxItem>[_sampleTx],
          receiveAddress: 'tb1qz3enhlaq8p0cgn7340g3qccxudeyzq23ruj880',
          lastSyncedAt: DateTime(2026, 4, 6, 8, 56),
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
        timestamp: DateTime(2026, 4, 6, 8, 56),
      ),
    ),
    backupReminderProvider.overrideWith(
      () => _FakeBackupReminderController(true),
    ),
    balancePrivacyProvider.overrideWith(
      () => _FakeBalancePrivacyController(false),
    ),
    lockControllerProvider.overrideWith(
      () => _FakeLockController(
        const AppLockState(
          isLockEnabled: true,
          isBiometricsEnabled: true,
          isBiometricAvailable: true,
          autoLockOption: AutoLockOption.after30Seconds,
          hasPin: true,
          isLocked: false,
          isBusy: false,
          failedAttempts: 0,
          message: null,
        ),
      ),
    ),
    dateTimeNowProvider.overrideWith(
      (ref) =>
          () => DateTime(2026, 4, 6, 9),
    ),
    suggestedFeeProvider.overrideWith(
      (ref) async => const FeeRate(satsPerVByte: 26),
    ),
  ];
}

final _sampleTx = TxItem(
  txId: 'efc102e6abc1234def5678',
  amountSats: 139518,
  timestamp: DateTime(2026, 3, 31, 8),
  isIncoming: true,
  status: TxItemStatus.confirmed,
  feeSats: 500,
  confirmations: 6,
);

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
