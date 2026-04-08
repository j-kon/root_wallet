import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/features/onboarding/presentation/pages/confirm_seed_page.dart';
import 'package:root_wallet/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/settings/presentation/pages/lock_screen.dart';
import 'package:root_wallet/features/settings/presentation/pages/security_page.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/create_wallet_page.dart';
import 'package:root_wallet/features/wallet/presentation/pages/restore_wallet_page.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final cases =
      <
        ({
          String name,
          Brightness brightness,
          Widget child,
          List<Override> overrides,
        })
      >[
        (
          name: 'welcome_light',
          brightness: Brightness.light,
          child: const WelcomePage(),
          overrides: const <Override>[],
        ),
        (
          name: 'welcome_dark',
          brightness: Brightness.dark,
          child: const WelcomePage(),
          overrides: const <Override>[],
        ),
        (
          name: 'create_wallet_light',
          brightness: Brightness.light,
          child: const CreateWalletPage(),
          overrides: _onboardingOverrides(),
        ),
        (
          name: 'create_wallet_dark',
          brightness: Brightness.dark,
          child: const CreateWalletPage(),
          overrides: _onboardingOverrides(),
        ),
        (
          name: 'restore_wallet_light',
          brightness: Brightness.light,
          child: const RestoreWalletPage(),
          overrides: _onboardingOverrides(),
        ),
        (
          name: 'restore_wallet_dark',
          brightness: Brightness.dark,
          child: const RestoreWalletPage(),
          overrides: _onboardingOverrides(),
        ),
        (
          name: 'backup_phrase_light',
          brightness: Brightness.light,
          child: const BackupSeedPage(
            requireReauth: false,
            isOnboardingFlow: true,
          ),
          overrides: _backupSeedOverrides(),
        ),
        (
          name: 'backup_phrase_dark',
          brightness: Brightness.dark,
          child: const BackupSeedPage(
            requireReauth: false,
            isOnboardingFlow: true,
          ),
          overrides: _backupSeedOverrides(),
        ),
        (
          name: 'confirm_seed_light',
          brightness: Brightness.light,
          child: const ConfirmSeedPage(),
          overrides: _onboardingOverrides(
            state: const OnboardingState(
              isBusy: false,
              challengeIndices: <int>[3, 7, 11],
            ),
          ),
        ),
        (
          name: 'confirm_seed_dark',
          brightness: Brightness.dark,
          child: const ConfirmSeedPage(),
          overrides: _onboardingOverrides(
            state: const OnboardingState(
              isBusy: false,
              challengeIndices: <int>[3, 7, 11],
            ),
          ),
        ),
        (
          name: 'security_light',
          brightness: Brightness.light,
          child: const SecurityPage(),
          overrides: _securityOverrides(locked: false),
        ),
        (
          name: 'security_dark',
          brightness: Brightness.dark,
          child: const SecurityPage(),
          overrides: _securityOverrides(locked: false),
        ),
        (
          name: 'lock_light',
          brightness: Brightness.light,
          child: const LockScreen(),
          overrides: _securityOverrides(locked: true),
        ),
        (
          name: 'lock_dark',
          brightness: Brightness.dark,
          child: const LockScreen(),
          overrides: _securityOverrides(locked: true),
        ),
      ];

  for (final testCase in cases) {
    testWidgets('onboarding/security golden ${testCase.name}', (tester) async {
      await _pumpGoldenPage(
        tester,
        brightness: testCase.brightness,
        overrides: testCase.overrides,
        child: testCase.child,
      );

      await expectLater(
        find.byKey(_goldenKey),
        matchesGoldenFile('goldens/onboarding_security_${testCase.name}.png'),
      );
    });
  }
}

const _goldenSurface = Size(390, 844);
const _goldenKey = ValueKey<String>('onboarding-security-golden');

Future<void> _pumpGoldenPage(
  WidgetTester tester, {
  required Brightness brightness,
  required Widget child,
  List<Override> overrides = const <Override>[],
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
      overrides: overrides,
      child: MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: RepaintBoundary(
          key: _goldenKey,
          child: ExcludeSemantics(child: child),
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
    ..._securityOverrides(locked: false),
  ];
}

List<Override> _securityOverrides({required bool locked}) {
  return <Override>[
    lockControllerProvider.overrideWith(
      () => _FakeLockController(
        AppLockState(
          isLockEnabled: true,
          isBiometricsEnabled: !locked,
          isBiometricAvailable: true,
          autoLockOption: AutoLockOption.after30Seconds,
          hasPin: true,
          isLocked: locked,
          isBusy: false,
          failedAttempts: 0,
          message: null,
        ),
      ),
    ),
  ];
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

class _FakeLockController extends LockController {
  _FakeLockController(this._state);

  final AppLockState _state;

  @override
  Future<AppLockState> build() async => _state;
}
