import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/features/rates/domain/entities/fx_rate.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/presentation/pages/wallet_home_page.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('wallet home shows offline banner and cached chip', (
    WidgetTester tester,
  ) async {
    await _pumpWalletHome(
      tester,
      state: WalletHomeState(
        balance: const Balance(confirmedSats: 15000),
        transactions: const [],
        receiveAddress: 'tb1qoffline',
        lastSyncedAt: DateTime(2026, 3, 31, 8, 0),
        isOffline: true,
        isSyncing: false,
      ),
    );
    expect(find.text('Cached data'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('Offline mode. Showing cached wallet data from'),
      300,
    );

    expect(
      find.textContaining('Offline mode. Showing cached wallet data from'),
      findsOneWidget,
    );
  });

  testWidgets('wallet home shows syncing banner and chip', (
    WidgetTester tester,
  ) async {
    await _pumpWalletHome(
      tester,
      state: WalletHomeState(
        balance: const Balance(confirmedSats: 15000),
        transactions: const [],
        receiveAddress: 'tb1qsyncing',
        lastSyncedAt: DateTime(2026, 3, 31, 8, 0),
        isOffline: false,
        isSyncing: true,
      ),
    );
    expect(find.text('Syncing testnet...'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining(
        'Refreshing wallet data from the public testnet network',
      ),
      300,
    );

    expect(
      find.textContaining(
        'Refreshing wallet data from the public testnet network',
      ),
      findsOneWidget,
    );
  });

  testWidgets('wallet home shows live data banner when synced', (
    WidgetTester tester,
  ) async {
    await _pumpWalletHome(
      tester,
      state: WalletHomeState(
        balance: const Balance(confirmedSats: 15000),
        transactions: const [],
        receiveAddress: 'tb1qlive',
        lastSyncedAt: DateTime.now(),
        isOffline: false,
        isSyncing: false,
      ),
    );
    await tester.scrollUntilVisible(
      find.textContaining('Live wallet data updated'),
      300,
    );

    expect(find.textContaining('Live wallet data updated'), findsOneWidget);
  });
}

Future<void> _pumpWalletHome(
  WidgetTester tester, {
  required WalletHomeState state,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        walletHomeControllerProvider.overrideWith(
          () => _FakeWalletHomeController(state),
        ),
        btcNgnRateProvider.overrideWith(
          (ref) async => FxRate(
            base: 'BTC',
            quote: 'NGN',
            value: 150000000.0,
            timestamp: DateTime(2026, 3, 31, 8),
          ),
        ),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        home: const WalletHomePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeWalletHomeController extends WalletHomeController {
  _FakeWalletHomeController(this._state);

  final WalletHomeState _state;

  @override
  Future<WalletHomeState> build() async => _state;
}
