import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/features/rates/domain/entities/fx_rate.dart';
import 'package:root_wallet/features/rates/presentation/providers/rates_providers.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/balance.dart';
import 'package:root_wallet/features/wallet/domain/entities/tx_item.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
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
    expect(find.textContaining('Cached'), findsWidgets);
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
      find.textContaining('Live wallet data refreshed'),
      300,
    );

    expect(find.textContaining('Live wallet data refreshed'), findsOneWidget);
  });

  testWidgets('wallet home shows View all and triggers onActivityRequested', (
    WidgetTester tester,
  ) async {
    var activityTapped = false;
    await _pumpWalletHome(
      tester,
      state: WalletHomeState(
        balance: const Balance(confirmedSats: 25000),
        transactions: [
          TxItem(
            txId: 'tx1234567890abcdef',
            amountSats: 5000,
            timestamp: DateTime(2026, 3, 31, 8, 0),
            isIncoming: true,
            status: TxItemStatus.confirmed,
          ),
        ],
        receiveAddress: 'tb1qlive',
        lastSyncedAt: DateTime.now(),
        isOffline: false,
        isSyncing: false,
      ),
      onActivityRequested: () {
        activityTapped = true;
      },
    );

    await tester.scrollUntilVisible(find.text('View all'), 300);
    expect(find.text('View all'), findsOneWidget);

    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    expect(activityTapped, isTrue);
  });

  testWidgets(
    'wallet home shows "Secure your recovery phrase" card when backup is not confirmed',
    (WidgetTester tester) async {
      await _pumpWalletHome(
        tester,
        isBackupConfirmed: false,
        state: WalletHomeState(
          balance: const Balance(confirmedSats: 15000),
          transactions: const [],
          receiveAddress: 'tb1qlive',
          lastSyncedAt: DateTime.now(),
          isOffline: false,
          isSyncing: false,
        ),
      );

      expect(find.text('Secure your recovery phrase'), findsOneWidget);
      expect(find.text('Back up now'), findsOneWidget);
      expect(find.text('Review phrase'), findsNothing);
      expect(find.text('Recovery phrase secured'), findsNothing);
    },
  );

  testWidgets(
    'wallet home completely hides recovery phrase container when backup is confirmed',
    (WidgetTester tester) async {
      await _pumpWalletHome(
        tester,
        isBackupConfirmed: true,
        state: WalletHomeState(
          balance: const Balance(confirmedSats: 15000),
          transactions: const [],
          receiveAddress: 'tb1qlive',
          lastSyncedAt: DateTime.now(),
          isOffline: false,
          isSyncing: false,
        ),
      );

      expect(find.text('Secure your recovery phrase'), findsNothing);
      expect(find.text('Back up now'), findsNothing);
      expect(find.text('Recovery phrase secured'), findsNothing);
      expect(find.text('Review phrase'), findsNothing);
    },
  );

  testWidgets(
    'wallet home top bar has no settings icon and displays notifications button',
    (WidgetTester tester) async {
      await _pumpWalletHome(
        tester,
        state: WalletHomeState(
          balance: const Balance(confirmedSats: 10000),
          transactions: const [],
          receiveAddress: 'tb1qlive',
          lastSyncedAt: DateTime.now(),
          isOffline: false,
          isSyncing: false,
        ),
      );

      // Settings icon MUST NOT be present in the home top bar
      expect(find.byIcon(Icons.settings_outlined), findsNothing);

      // Notifications button MUST be present
      expect(
        find.byKey(const ValueKey('home_notifications_button')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    },
  );

  testWidgets(
    'tapping notifications button triggers onNotificationsRequested callback',
    (WidgetTester tester) async {
      var notificationsTapped = false;
      await _pumpWalletHome(
        tester,
        onNotificationsRequested: () {
          notificationsTapped = true;
        },
        state: WalletHomeState(
          balance: const Balance(confirmedSats: 10000),
          transactions: const [],
          receiveAddress: 'tb1qlive',
          lastSyncedAt: DateTime.now(),
          isOffline: false,
          isSyncing: false,
        ),
      );

      await tester.tap(find.byKey(const ValueKey('home_notifications_button')));
      await tester.pumpAndSettle();

      expect(notificationsTapped, isTrue);
    },
  );

  testWidgets(
    'wallet switcher chip displays ACTIVE WALLET label and triggers switcher modal',
    (WidgetTester tester) async {
      await _pumpWalletHome(
        tester,
        state: WalletHomeState(
          balance: const Balance(confirmedSats: 10000),
          transactions: const [],
          receiveAddress: 'tb1qlive',
          lastSyncedAt: DateTime.now(),
          isOffline: false,
          isSyncing: false,
        ),
      );

      // Active wallet label should be prominent
      expect(find.text('ACTIVE WALLET'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wallet_switcher_trigger')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);

      // Tap to open modal
      await tester.tap(find.byKey(const ValueKey('wallet_switcher_trigger')));
      await tester.pumpAndSettle();

      // Modal bottom sheet should appear with Your Wallets
      expect(find.text('Your Wallets'), findsOneWidget);
    },
  );

  testWidgets(
    'wallet switcher displays WATCH ONLY badge when active wallet is watch-only',
    (WidgetTester tester) async {
      final watchOnlyWallet = WalletRecord(
        id: 'w_watch',
        name: 'Cold Storage Vault',
        type: WalletType.watchOnly,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime(2026, 1, 1),
      );

      await _pumpWalletHome(
        tester,
        activeWallet: watchOnlyWallet,
        state: WalletHomeState(
          balance: const Balance(confirmedSats: 50000),
          transactions: const [],
          receiveAddress: 'tb1qwatch',
          lastSyncedAt: DateTime.now(),
          isOffline: false,
          isSyncing: false,
        ),
      );

      expect(find.text('ACTIVE WALLET'), findsOneWidget);
      expect(find.text('Cold Storage Vault'), findsOneWidget);
      expect(find.text('WATCH ONLY'), findsWidgets);
    },
  );
}

Future<void> _pumpWalletHome(
  WidgetTester tester, {
  required WalletHomeState state,
  VoidCallback? onActivityRequested,
  VoidCallback? onNotificationsRequested,
  bool isBackupConfirmed = false,
  WalletRecord? activeWallet,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (activeWallet != null)
          activeWalletRecordProvider.overrideWithValue(activeWallet),
        walletHomeControllerProvider.overrideWith(
          () => _FakeWalletHomeController(state),
        ),
        backupReminderProvider.overrideWith(
          () => _FakeBackupReminderController(isBackupConfirmed),
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
        home: WalletHomePage(
          onActivityRequested: onActivityRequested,
          onNotificationsRequested: onNotificationsRequested,
        ),
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

class _FakeBackupReminderController extends BackupReminderController {
  _FakeBackupReminderController(this._value);

  final bool _value;

  @override
  Future<bool> build() async => _value;
}
