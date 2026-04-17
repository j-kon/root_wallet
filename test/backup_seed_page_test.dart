import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:root_wallet/features/wallet/presentation/pages/backup_seed_page.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

void main() {
  testWidgets('backup phrase requires both safety acknowledgements', (
    tester,
  ) async {
    late _FakeOnboardingController onboardingController;

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 1200);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingControllerProvider.overrideWith((ref) {
            onboardingController = _FakeOnboardingController(ref);
            return onboardingController;
          }),
          recoveryPhraseProvider.overrideWith(
            (ref) async =>
                'abandon ability able about above absent absorb abstract absurd abuse access accident',
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          routes: {
            AppRoutes.confirmSeed: (_) =>
                const Scaffold(body: Text('Confirm seed target')),
          },
          home: const BackupSeedPage(
            requireReauth: false,
            isOnboardingFlow: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.textContaining('12-word recovery phrase'), findsOneWidget);
    await tester.drag(find.byType(Scrollable), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('I wrote it down'), findsOneWidget);

    await tester.tap(find.text('I wrote it down'));
    await tester.pumpAndSettle();
    expect(onboardingController.prepareSeedChallengeCalls, 0);
    expect(find.text('Confirm seed target'), findsNothing);

    await tester.tap(find.text('I wrote the phrase down offline.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I wrote it down'));
    await tester.pumpAndSettle();
    expect(onboardingController.prepareSeedChallengeCalls, 0);
    expect(find.text('Confirm seed target'), findsNothing);

    await tester.tap(
      find.text('I understand Root Wallet cannot recover it for me.'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('I wrote it down'));
    await tester.pumpAndSettle();

    expect(onboardingController.prepareSeedChallengeCalls, 1);
    expect(find.text('Confirm seed target'), findsOneWidget);
  });
}

class _FakeOnboardingController extends OnboardingController {
  _FakeOnboardingController(super.ref);

  int prepareSeedChallengeCalls = 0;

  @override
  Future<void> prepareSeedChallenge() async {
    prepareSeedChallengeCalls += 1;
    state = state.copyWith(challengeIndices: const <int>[3, 7, 11]);
  }
}
