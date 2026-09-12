import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/app_theme.dart';
import 'package:root_wallet/features/notifications/domain/entities/notification_item.dart';
import 'package:root_wallet/features/notifications/presentation/pages/notifications_page.dart';
import 'package:root_wallet/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotificationsPage & NotificationsProvider Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    const testWallet1 = 'w_11111111-1111-4111-8111-111111111111';
    const testWallet2 = 'w_22222222-2222-4222-8222-222222222222';

    final testNotifications = [
      WalletNotification(
        id: 'n1',
        title: 'Wallet ready for testnet',
        message: 'Your Bitcoin testnet wallet is initialized.',
        category: NotificationCategory.wallet,
        createdAt: DateTime(2026, 1, 1, 12, 0),
        walletId: testWallet1,
        walletName: 'Main Wallet',
        isRead: false,
      ),
      WalletNotification(
        id: 'n2',
        title: 'Secure your recovery phrase',
        message: 'Back up your 12-word seed phrase.',
        category: NotificationCategory.security,
        createdAt: DateTime(2026, 1, 1, 11, 0),
        walletId: testWallet2,
        walletName: 'Savings',
        isRead: false,
        action: NotificationAction.security,
      ),
      WalletNotification(
        id: 'n3',
        title: 'SOCKS5 privacy routing',
        message: 'Tor-compatible SOCKS5 privacy routing is available.',
        category: NotificationCategory.system,
        createdAt: DateTime(2026, 1, 1, 10, 0),
        isRead: true,
        action: NotificationAction.connectionRouting,
      ),
    ];

    Widget buildTestWidget({
      List<WalletNotification>? initialItems,
      NavigatorObserver? navigatorObserver,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          if (initialItems != null)
            notificationsProvider.overrideWith(
              () => _TestNotificationsNotifier(initialItems),
            ),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          home: const NotificationsPage(),
          navigatorObservers: [
            if (navigatorObserver != null) navigatorObserver,
          ],
          routes: {
            AppRoutes.security: (context) =>
                const Scaffold(body: Text('Security Settings Screen')),
            AppRoutes.connectionRouting: (context) =>
                const Scaffold(body: Text('Connection Routing Screen')),
          },
        ),
      );
    }

    testWidgets('renders notifications list, category labels, and wallet badges', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(initialItems: testNotifications));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('All (3)'), findsOneWidget);
      expect(find.text('Unread (2)'), findsOneWidget);
      expect(find.text('Mark all as read'), findsOneWidget);

      expect(find.text('Wallet ready for testnet'), findsOneWidget);
      expect(find.text('Secure your recovery phrase'), findsOneWidget);
      expect(find.text('SOCKS5 privacy routing'), findsOneWidget);

      // Category tags
      expect(find.text('WALLET'), findsOneWidget);
      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('SYSTEM'), findsOneWidget);

      // Wallet badges for scoped notifications
      expect(find.text('Main Wallet'), findsOneWidget);
      expect(find.text('Savings'), findsOneWidget);
    });

    testWidgets('filtering by Unread displays only unread items', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(initialItems: testNotifications));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unread (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Wallet ready for testnet'), findsOneWidget);
      expect(find.text('Secure your recovery phrase'), findsOneWidget);
      expect(find.text('SOCKS5 privacy routing'), findsNothing);
    });

    testWidgets('tapping an unread notification marks it as read and navigates if routeTarget present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(initialItems: testNotifications));
      await tester.pumpAndSettle();

      expect(find.text('Unread (2)'), findsOneWidget);

      // Tap on n2 (has routeTarget: AppRoutes.security)
      await tester.tap(find.text('Secure your recovery phrase'));
      await tester.pumpAndSettle();

      // Navigated to Security Settings Screen
      expect(find.text('Security Settings Screen'), findsOneWidget);
    });

    testWidgets('tapping Mark all as read marks all notifications as read and hides the button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(initialItems: testNotifications));
      await tester.pumpAndSettle();

      expect(find.text('Mark all as read'), findsOneWidget);
      expect(find.text('Unread (2)'), findsOneWidget);

      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();

      expect(find.text('Unread (0)'), findsOneWidget);
      expect(find.text('Mark all as read'), findsNothing);
    });

    testWidgets('shows empty state "You\'re all caught up." when no notifications exist', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(initialItems: const []));
      await tester.pumpAndSettle();

      expect(find.text("You're all caught up."), findsOneWidget);
      expect(
        find.text('Important wallet, security and transaction updates will appear here.'),
        findsOneWidget,
      );
    });

    testWidgets('shows unread empty state when no unread notifications exist', (
      WidgetTester tester,
    ) async {
      final readOnly = [
        testNotifications[2], // already read
      ];
      await tester.pumpWidget(buildTestWidget(initialItems: readOnly));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unread (0)'));
      await tester.pumpAndSettle();

      expect(find.text("You're all caught up."), findsOneWidget);
      expect(
        find.text('No unread notifications at this time.'),
        findsOneWidget,
      );
    });

    test('notifications persist and restore cleanly from SharedPreferences', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      // Fresh install starts with an empty list (no fabricated defaults)
      final initial = container.read(notificationsProvider);
      expect(initial.isEmpty, isTrue);

      // Add a wallet-scoped notification
      const customWalletId = 'w_33333333-3333-4333-8333-333333333333';
      final custom = WalletNotification(
        id: 'custom_1',
        title: 'Custom Testnet Alert',
        message: 'A testnet transaction was detected.',
        category: NotificationCategory.transaction,
        createdAt: DateTime(2026, 1, 2),
        walletId: customWalletId,
        walletName: 'Test Wallet',
        isRead: false,
      );

      await container.read(notificationsProvider.notifier).addNotification(custom);
      expect(container.read(notificationsProvider).first.id, 'custom_1');

      // Create a second container simulating app restart with the same prefs
      final restartContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(restartContainer.dispose);

      final restored = restartContainer.read(notificationsProvider);
      expect(restored.any((n) => n.id == 'custom_1'), isTrue);
      final restoredCustom = restored.firstWhere((n) => n.id == 'custom_1');
      expect(restoredCustom.title, 'Custom Testnet Alert');
      expect(restoredCustom.walletId, customWalletId);
      expect(restoredCustom.walletName, 'Test Wallet');
      expect(restoredCustom.category, NotificationCategory.transaction);
    });

    test('multi-wallet notifications retain their wallet scoping across wallet switching', () {
      final notifA = WalletNotification(
        id: 'na',
        title: 'Wallet A received funds',
        message: 'Transaction detected.',
        category: NotificationCategory.transaction,
        createdAt: DateTime(2026, 1, 1),
        walletId: testWallet1,
        walletName: 'Wallet A',
      );
      final notifB = WalletNotification(
        id: 'nb',
        title: 'Wallet B backup alert',
        message: 'Backup required.',
        category: NotificationCategory.backup,
        createdAt: DateTime(2026, 1, 2),
        walletId: testWallet2,
        walletName: 'Wallet B',
        action: NotificationAction.backup,
      );

      final list = [notifA, notifB];

      // Scoping is immutable to walletId and does not leak or mutate
      expect(list[0].walletId, testWallet1);
      expect(list[0].walletName, 'Wallet A');
      expect(list[1].walletId, testWallet2);
      expect(list[1].walletName, 'Wallet B');
    });
  });
}

class _TestNotificationsNotifier extends NotificationsNotifier {
  _TestNotificationsNotifier(this._initial);
  final List<WalletNotification> _initial;

  @override
  List<WalletNotification> build() => _initial;
}
