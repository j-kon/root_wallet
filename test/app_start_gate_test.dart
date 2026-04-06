import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/routing/app_start_gate.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/features/onboarding/presentation/providers/app_start_providers.dart';

void main() {
  testWidgets(
    'app start gate shows onboarding when destination is onboarding',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStartControllerProvider.overrideWith(
              () => _DataAppStartController(
                const AppStartState(
                  destination: AppStartDestination.onboarding,
                  walletExists: false,
                  backupConfirmed: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            darkTheme: buildAppTheme(brightness: Brightness.dark),
            home: const AppStartGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create wallet'), findsOneWidget);
      expect(find.text('Restore wallet'), findsOneWidget);
    },
  );

  testWidgets('app start gate shows branded loading state while resolving', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartControllerProvider.overrideWith(
            () => _LoadingAppStartController(),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          home: const AppStartGate(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Preparing wallet...'), findsOneWidget);
  });

  testWidgets('app start gate shows retry state on error', (
    WidgetTester tester,
  ) async {
    var refreshCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartControllerProvider.overrideWith(
            () => _ErrorAppStartController(onRefresh: () => refreshCalls += 1),
          ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          home: const AppStartGate(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to initialize app state'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(refreshCalls, 1);
  });
}

class _DataAppStartController extends AppStartController {
  _DataAppStartController(this._state);

  final AppStartState _state;

  @override
  Future<AppStartState> build() async => _state;
}

class _LoadingAppStartController extends AppStartController {
  final Completer<AppStartState> _completer = Completer<AppStartState>();

  @override
  Future<AppStartState> build() => _completer.future;
}

class _ErrorAppStartController extends AppStartController {
  _ErrorAppStartController({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Future<AppStartState> build() async {
    throw Exception('failed to load start state');
  }

  @override
  Future<void> refresh() async {
    onRefresh();
  }
}
