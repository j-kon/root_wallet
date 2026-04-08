import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/features/settings/presentation/pages/security_page.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';

void main() {
  testWidgets('security page renders lock controls for protected wallets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          home: const SecurityPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protected by app lock'), findsOneWidget);
    expect(find.text('Enable biometrics'), findsOneWidget);
    expect(
      find.byType(DropdownButtonFormField<AutoLockOption>),
      findsOneWidget,
    );
    expect(find.text('After 30s'), findsAtLeastNWidgets(1));

    await tester.scrollUntilVisible(
      find.text('Change PIN'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('Lock now'), findsOneWidget);
  });
}

class _FakeLockController extends LockController {
  _FakeLockController(this._state);

  final AppLockState _state;

  @override
  Future<AppLockState> build() async => _state;
}
