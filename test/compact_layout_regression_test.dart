import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/features/onboarding/presentation/pages/confirm_seed_page.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:root_wallet/features/rates/domain/entities/fx_rate.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/receive/presentation/pages/receive_page.dart';
import 'package:root_wallet/features/send/domain/entities/fee_rate.dart';
import 'package:root_wallet/features/send/presentation/pages/send_page.dart';
import 'package:root_wallet/features/send/presentation/pages/send_success_page.dart';
import 'package:root_wallet/features/send/presentation/providers/send_providers.dart';
import 'package:root_wallet/features/settings/presentation/pages/about_page.dart';
import 'package:root_wallet/features/settings/presentation/pages/lock_screen.dart';
import 'package:root_wallet/features/settings/presentation/pages/security_page.dart';
import 'package:root_wallet/features/settings/presentation/pages/settings_page.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/create_wallet_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/restore_wallet_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/transaction_details_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/wallet_home_page.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final compactThemes = <Brightness>[Brightness.light, Brightness.dark];

  for (final brightness in compactThemes) {
    final themeName = brightness == Brightness.dark ? 'dark' : 'light';

    testWidgets('welcome page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        child: const WelcomePage(),
      );

      await _scrollUntilVisible(tester, find.text('Restore wallet'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('Create wallet'), findsOneWidget);
      expect(find.text('Restore wallet'), findsOneWidget);
    });

    testWidgets('create wallet page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        overrides: _onboardingOverrides(),
        child: const CreateWalletPage(),
      );

      await _scrollUntilVisible(tester, find.text('Create wallet'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('What happens next'), findsOneWidget);
      expect(find.text('Create wallet'), findsWidgets);
    });

    testWidgets('restore wallet page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        overrides: _onboardingOverrides(),
        child: const RestoreWalletPage(),
      );

      await _scrollUntilVisible(tester, find.text('Restore wallet'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('Recovery phrase'), findsWidgets);
      expect(find.text('Restore wallet'), findsWidgets);
    });

    testWidgets('backup seed page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        overrides: _backupSeedOverrides(),
        child: const BackupSeedPage(
          requireReauth: false,
          isOnboardingFlow: true,
        ),
      );

      await _scrollUntilVisible(tester, find.text('I wrote it down'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('Recovery phrase'), findsOneWidget);
      expect(find.text('I wrote it down'), findsOneWidget);
    });

    testWidgets('confirm seed page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        overrides: _onboardingOverrides(
          state: const OnboardingState(
            isBusy: false,
            challengeIndices: <int>[3, 7, 11],
          ),
        ),
        child: const ConfirmSeedPage(),
      );

      await _scrollUntilVisible(tester, find.text('Confirm backup'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('Word #3'), findsOneWidget);
      expect(find.text('Confirm backup'), findsOneWidget);
    });

    testWidgets('wallet home renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        overrides: _walletPageOverrides(),
        child: const WalletHomePage(),
      );

      await _scrollUntilVisible(tester, find.text('Recent activity'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
    });

    testWidgets('receive page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        overrides: _walletPageOverrides(),
        child: const ReceivePage(),
      );

      await _scrollUntilVisible(
        tester,
        find.textContaining('Only send BTC on testnet'),
      );

      _expectNoFrameworkErrors(tester);
      expect(find.text('Receive address'), findsOneWidget);
      expect(find.text('Copy address'), findsWidgets);
    });

    testWidgets('send page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        overrides: _sendPageOverrides(),
        child: const SendPage(),
      );

      await _scrollUntilVisible(tester, find.text('Transfer summary'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('Send BTC'), findsOneWidget);
      expect(find.text('Transfer summary'), findsOneWidget);
    });

    testWidgets('settings page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        sharedPreferencesValues: <String, Object>{
          'settings.backup_confirmed': true,
          'settings.hide_balances': false,
          'settings.theme_mode': brightness == Brightness.dark
              ? 'dark'
              : 'light',
        },
        overrides: _settingsPageOverrides(),
        child: const SettingsPage(),
      );

      expect(find.text('Appearance'), findsOneWidget);
      await _scrollUntilVisible(tester, find.text('Help and app info'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('Help and app info'), findsOneWidget);
    });

    testWidgets('security page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        overrides: _securityPageOverrides(),
        child: const SecurityPage(),
      );

      expect(find.text('Protected by app lock'), findsOneWidget);
      await _scrollUntilVisible(tester, find.text('PIN management'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('PIN management'), findsOneWidget);
    });

    testWidgets('about page renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        child: const AboutPage(),
      );

      _expectNoFrameworkErrors(tester);
      expect(find.text('Design principles'), findsOneWidget);

      await _scrollUntilVisible(tester, find.text('Support'));
      expect(find.text('Support'), findsOneWidget);
    });

    testWidgets('lock screen renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        overrides: _lockedStateOverrides(),
        child: const LockScreen(),
      );

      _expectNoFrameworkErrors(tester);
      expect(find.text('Unlock Root Wallet'), findsOneWidget);
      expect(find.text('Enter your 6-digit PIN to continue.'), findsOneWidget);
    });

    testWidgets('transaction details renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        sharedPreferencesValues: const <String, Object>{
          'settings.hide_balances': false,
        },
        routeArguments: _sampleTx,
        child: const TransactionDetailsPage(),
      );

      await _scrollUntilVisible(tester, find.text('Transaction fingerprint'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('Transaction'), findsOneWidget);
      expect(find.text('Transaction fingerprint'), findsOneWidget);
    });

    testWidgets('send success renders on compact $themeName screens', (
      tester,
    ) async {
      await _pumpCompactPage(
        tester,
        brightness: brightness,
        routeArguments: SendSuccessPageArgs(
          txId: _sampleTx.txId,
          amountSats: 139518,
          feeSats: 500,
          sentAt: DateTime(2026, 3, 31, 9, 30),
        ),
        child: const SendSuccessPage(),
      );

      await _scrollUntilVisible(tester, find.text('Transaction ID'));

      _expectNoFrameworkErrors(tester);
      expect(find.text('Transfer sent'), findsOneWidget);
      expect(find.text('Transaction ID'), findsOneWidget);
    });
  }
}

const _compactSurface = Size(320, 740);
final _capturedFlutterErrors = <FlutterErrorDetails>[];

final _sampleTx = TxItem(
  txId: 'efc102e6abc1234def5678',
  amountSats: 139518,
  timestamp: DateTime(2026, 3, 31, 8),
  isIncoming: true,
  status: TxItemStatus.confirmed,
  feeSats: 500,
  confirmations: 6,
);

Future<void> _pumpCompactPage(
  WidgetTester tester, {
  required Brightness brightness,
  required Widget child,
  List<Override> overrides = const <Override>[],
  Map<String, Object> sharedPreferencesValues = const <String, Object>{},
  Object? routeArguments,
}) async {
  SharedPreferences.setMockInitialValues(sharedPreferencesValues);
  _capturedFlutterErrors.clear();
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _compactSurface;
  addTearDown(() {
    _capturedFlutterErrors.clear();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final previousFlutterErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    _capturedFlutterErrors.add(details);
  };
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          builder: (context, widget) =>
              ExcludeSemantics(child: widget ?? const SizedBox.shrink()),
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: RouteSettings(arguments: routeArguments),
            builder: (_) => child,
          ),
        ),
      ),
    );

    await _stabilizeFrames(tester);
  } finally {
    FlutterError.onError = previousFlutterErrorHandler;
  }
}

void _expectNoFrameworkErrors(WidgetTester tester) {
  if (_capturedFlutterErrors.isNotEmpty) {
    final message = _capturedFlutterErrors
        .map((details) => details.toString())
        .join('\n\n');
    fail('Captured Flutter errors:\n$message');
  }

  expect(tester.takeException(), isNull);
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) {
      throw StateError('Target not found for ensureVisible: $target');
    }
    await tester.scrollUntilVisible(target, 240, scrollable: scrollables.first);
    await _stabilizeFrames(tester);
    return;
  }

  final targetFinder = target.first;
  final hasScrollableAncestor = find
      .ancestor(of: targetFinder, matching: find.byType(Scrollable))
      .evaluate()
      .isNotEmpty;

  if (hasScrollableAncestor) {
    await tester.ensureVisible(targetFinder);
  }
  await _stabilizeFrames(tester);
}

Future<void> _stabilizeFrames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

List<Override> _walletPageOverrides() {
  return <Override>[
    walletHomeControllerProvider.overrideWith(
      () => _FakeWalletHomeController(
        WalletHomeState(
          balance: const Balance(confirmedSats: 139518, pendingSats: 1200),
          transactions: <TxItem>[_sampleTx],
          receiveAddress: 'tb1qz3enhlaq8p0cgn7340g3qccxudeyzq23ruj880',
          lastSyncedAt: DateTime(2026, 3, 31, 8),
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
        timestamp: DateTime(2026, 3, 31, 8),
      ),
    ),
    backupReminderProvider.overrideWith(
      () => _FakeBackupReminderController(true),
    ),
    balancePrivacyProvider.overrideWith(
      () => _FakeBalancePrivacyController(false),
    ),
  ];
}

List<Override> _sendPageOverrides() {
  return <Override>[
    ..._walletPageOverrides(),
    suggestedFeeProvider.overrideWith(
      (ref) async => const FeeRate(satsPerVByte: 26),
    ),
  ];
}

List<Override> _settingsPageOverrides() {
  return <Override>[
    ..._walletPageOverrides(),
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
  ];
}

List<Override> _securityPageOverrides() {
  return <Override>[
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
  ];
}

List<Override> _lockedStateOverrides() {
  return <Override>[
    lockControllerProvider.overrideWith(
      () => _FakeLockController(
        const AppLockState(
          isLockEnabled: true,
          isBiometricsEnabled: false,
          isBiometricAvailable: false,
          autoLockOption: AutoLockOption.after30Seconds,
          hasPin: true,
          isLocked: true,
          isBusy: false,
          failedAttempts: 0,
          message: null,
        ),
      ),
    ),
  ];
}

List<Override> _onboardingOverrides({
  OnboardingState state = const OnboardingState(
    isBusy: false,
    challengeIndices: <int>[],
  ),
}) {
  return <Override>[
    onboardingControllerProvider.overrideWith(
      (ref) => _FakeOnboardingController(ref, state),
    ),
  ];
}

List<Override> _backupSeedOverrides() {
  return <Override>[
    ..._onboardingOverrides(),
    recoveryPhraseProvider.overrideWith(
      (ref) async =>
          'abandon ability able about above absent absorb abstract absurd abuse access accident',
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

class _FakeOnboardingController extends OnboardingController {
  _FakeOnboardingController(super.ref, this._initialState) {
    state = _initialState;
  }

  final OnboardingState _initialState;

  @override
  Future<bool> createWallet() async => true;

  @override
  Future<bool> restoreWallet(String mnemonic) async => true;

  @override
  Future<void> prepareSeedChallenge() async {
    state = state.copyWith(
      challengeIndices: _initialState.challengeIndices,
      clearError: true,
    );
  }

  @override
  Future<bool> confirmBackup(Map<int, String> answers) async => true;
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
