import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/features/notifications/domain/entities/notification_item.dart';
import 'package:root_wallet/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_script_type.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const testWalletAId = 'w_11111111-1111-4111-8111-111111111111';
const testWalletBId = 'w_22222222-2222-4222-8222-222222222222';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('WalletNotification Entity Validation & Invariants', () {
    test('valid notification constructs and serializes cleanly', () {
      final notif = WalletNotification(
        id: 'notif_1',
        title: 'Transaction detected',
        message: 'A new transaction was detected on testnet.',
        category: NotificationCategory.transaction,
        createdAt: DateTime(2026, 1, 1, 12, 0),
        walletId: testWalletAId,
        walletName: 'Main Wallet',
        isRead: false,
        action: NotificationAction.security,
      );

      expect(notif.id, 'notif_1');
      expect(notif.action, NotificationAction.security);

      final json = notif.toJson();
      expect(json['id'], 'notif_1');
      expect(json['action'], 'security');

      final restored = WalletNotification.fromJson(json);
      expect(restored, equals(notif));
    });

    test('rejects empty or whitespace ID or ID > 128 characters', () {
      expect(
        () => WalletNotification(
          id: '',
          title: 'Title',
          message: 'Message',
          category: NotificationCategory.system,
          createdAt: DateTime.now(),
        ),
        throwsFormatException,
      );

      expect(
        () => WalletNotification(
          id: '   ',
          title: 'Title',
          message: 'Message',
          category: NotificationCategory.system,
          createdAt: DateTime.now(),
        ),
        throwsFormatException,
      );

      expect(
        () => WalletNotification(
          id: 'a' * 129,
          title: 'Title',
          message: 'Message',
          category: NotificationCategory.system,
          createdAt: DateTime.now(),
        ),
        throwsFormatException,
      );
    });

    test('rejects empty or whitespace title or title > 256 characters', () {
      expect(
        () => WalletNotification(
          id: 'id_1',
          title: '',
          message: 'Message',
          category: NotificationCategory.system,
          createdAt: DateTime.now(),
        ),
        throwsFormatException,
      );

      expect(
        () => WalletNotification(
          id: 'id_1',
          title: '   ',
          message: 'Message',
          category: NotificationCategory.system,
          createdAt: DateTime.now(),
        ),
        throwsFormatException,
      );

      expect(
        () => WalletNotification(
          id: 'id_1',
          title: 'a' * 257,
          message: 'Message',
          category: NotificationCategory.system,
          createdAt: DateTime.now(),
        ),
        throwsFormatException,
      );
    });

    test('rejects message length exceeding 1024 characters', () {
      expect(
        () => WalletNotification(
          id: 'id_1',
          title: 'Valid title',
          message: 'm' * 1025,
          category: NotificationCategory.system,
          createdAt: DateTime.now(),
        ),
        throwsFormatException,
      );
    });

    test('rejects walletName provided without walletId', () {
      expect(
        () => WalletNotification(
          id: 'id_1',
          title: 'Valid title',
          message: 'Valid message',
          category: NotificationCategory.wallet,
          createdAt: DateTime.now(),
          walletName: 'Orphan Wallet Name',
        ),
        throwsFormatException,
      );
    });

    test('rejects non-canonical or traversal walletId', () {
      expect(
        () => WalletNotification(
          id: 'id_1',
          title: 'Valid title',
          message: 'Valid message',
          category: NotificationCategory.wallet,
          createdAt: DateTime.now(),
          walletId: '../../etc/passwd',
        ),
        throwsFormatException,
      );

      expect(
        () => WalletNotification(
          id: 'id_1',
          title: 'Valid title',
          message: 'Valid message',
          category: NotificationCategory.wallet,
          createdAt: DateTime.now(),
          walletId: 'arbitrary_wallet_id',
        ),
        throwsFormatException,
      );
    });

    test('rejects backup action when walletId is null', () {
      expect(
        () => WalletNotification(
          id: 'id_1',
          title: 'Backup required',
          message: 'Backup words',
          category: NotificationCategory.backup,
          createdAt: DateTime.now(),
          action: NotificationAction.backup,
          walletId: null,
        ),
        throwsFormatException,
      );
    });

    test('fromJson strictly validates json fields', () {
      // Malformed createdAt
      expect(
        () => WalletNotification.fromJson({
          'id': 'n1',
          'title': 'T',
          'message': 'M',
          'category': 'system',
          'createdAt': 'not-a-date',
          'isRead': false,
        }),
        throwsFormatException,
      );

      // Unknown category
      expect(
        () => WalletNotification.fromJson({
          'id': 'n1',
          'title': 'T',
          'message': 'M',
          'category': 'non_existent_category',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': false,
        }),
        throwsFormatException,
      );

      // Non-boolean isRead
      expect(
        () => WalletNotification.fromJson({
          'id': 'n1',
          'title': 'T',
          'message': 'M',
          'category': 'system',
          'createdAt': DateTime.now().toIso8601String(),
          'isRead': 'true',
        }),
        throwsFormatException,
      );
    });
  });

  group('Watch-Only Backup Protection (Requirement 6)', () {
    test('never generates backup reminder for watch-only wallet', () {
      final watchOnlyWallet = WalletRecord(
        id: testWalletAId,
        name: 'Watch Only Vault',
        type: WalletType.watchOnly,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime(2026, 1, 1),
      );

      final reminder = WalletNotification.createBackupReminder(
        wallet: watchOnlyWallet,
      );

      expect(reminder, isNull);
    });

    test('generates valid backup reminder for standard software wallet', () {
      final standardWallet = WalletRecord(
        id: testWalletAId,
        name: 'Primary Spending',
        type: WalletType.signing,
        scriptType: WalletScriptType.nativeSegwit,
        network: 'testnet',
        createdAt: DateTime(2026, 1, 1),
      );

      final reminder = WalletNotification.createBackupReminder(
        wallet: standardWallet,
      );

      expect(reminder, isNotNull);
      expect(reminder!.walletId, testWalletAId);
      expect(reminder.action, NotificationAction.backup);
      expect(reminder.category, NotificationCategory.backup);
    });
  });

  group('Decoy Mode Isolation & Privacy (Requirements 1, 2, 20)', () {
    test('unread count is 0 and visible notifications are empty in decoy mode', () async {
      final realNotif = WalletNotification(
        id: 'real_1',
        title: 'Transaction detected',
        message: 'Transaction detected.',
        category: NotificationCategory.transaction,
        createdAt: DateTime.now(),
        walletId: testWalletAId,
        walletName: 'Real Secret Wallet',
        isRead: false,
      );

      await prefs.setString(
        'root_wallet_notifications_v1',
        jsonEncode([realNotif.toJson()]),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      // Initially in normal mode
      expect(container.read(isDecoyModeProvider), isFalse);
      expect(container.read(unreadNotificationCountProvider), 1);
      expect(container.read(visibleNotificationsProvider).length, 1);
      expect(container.read(notificationsProvider).length, 1);

      // Activate Decoy Mode
      container.read(isDecoyModeProvider.notifier).setDecoyActive(true);
      expect(container.read(isDecoyModeProvider), isTrue);

      // In decoy mode: count must be 0, visible must be empty
      expect(container.read(unreadNotificationCountProvider), 0);
      expect(container.read(visibleNotificationsProvider), isEmpty);

      // Real notifications in underlying provider and storage are unharmed
      expect(container.read(notificationsProvider).length, 1);
      expect(
        prefs.getString('root_wallet_notifications_v1'),
        contains('Real Secret Wallet'),
      );

      // Deactivate Decoy Mode: real notifications reappear
      container.read(isDecoyModeProvider.notifier).setDecoyActive(false);
      expect(container.read(isDecoyModeProvider), isFalse);
      expect(container.read(unreadNotificationCountProvider), 1);
      expect(container.read(visibleNotificationsProvider).length, 1);
    });
  });

  group('Retention Cap, Deduplication, and Sorting (Requirements 12, 13, 14)', () {
    test('caps storage at 200 newest items', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(notificationsProvider.notifier);

      for (int i = 0; i < 205; i++) {
        await notifier.addNotification(
          WalletNotification(
            id: 'n_$i',
            title: 'Title $i',
            message: 'Message $i',
            category: NotificationCategory.system,
            createdAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
          ),
        );
      }

      final items = container.read(notificationsProvider);
      expect(items.length, 200);
      // Newest should be n_204
      expect(items.first.id, 'n_204');
      // Oldest retained should be n_5
      expect(items.last.id, 'n_5');
    });

    test('deduplicates by updating existing notification ID', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(notificationsProvider.notifier);

      await notifier.addNotification(
        WalletNotification(
          id: 'dup_test',
          title: 'Original Title',
          message: 'Original Message',
          category: NotificationCategory.system,
          createdAt: DateTime(2026, 1, 1),
          isRead: false,
        ),
      );

      expect(container.read(notificationsProvider).length, 1);
      expect(container.read(notificationsProvider).first.title, 'Original Title');

      await notifier.addNotification(
        WalletNotification(
          id: 'dup_test',
          title: 'Updated Title',
          message: 'Updated Message',
          category: NotificationCategory.system,
          createdAt: DateTime(2026, 1, 2),
          isRead: true,
        ),
      );

      final items = container.read(notificationsProvider);
      expect(items.length, 1);
      expect(items.first.title, 'Updated Title');
      expect(items.first.isRead, isTrue);
    });

    test('orders notifications newest-first deterministically', () async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(notificationsProvider.notifier);

      final oldest = WalletNotification(
        id: 'oldest',
        title: 'Oldest',
        message: 'Message',
        category: NotificationCategory.system,
        createdAt: DateTime(2026, 1, 1),
      );
      final newest = WalletNotification(
        id: 'newest',
        title: 'Newest',
        message: 'Message',
        category: NotificationCategory.system,
        createdAt: DateTime(2026, 1, 3),
      );
      final middle = WalletNotification(
        id: 'middle',
        title: 'Middle',
        message: 'Message',
        category: NotificationCategory.system,
        createdAt: DateTime(2026, 1, 2),
      );

      await notifier.addNotification(oldest);
      await notifier.addNotification(newest);
      await notifier.addNotification(middle);

      final items = container.read(notificationsProvider);
      expect(items.map((i) => i.id).toList(), ['newest', 'middle', 'oldest']);
    });
  });

  group('Wallet Deletion Isolation (Requirement 18)', () {
    test('removeNotificationsForWallet only removes notifications for the deleted wallet', () async {
      final notifA = WalletNotification(
        id: 'notif_a',
        title: 'Wallet A alert',
        message: 'Transaction detected.',
        category: NotificationCategory.transaction,
        createdAt: DateTime(2026, 1, 1),
        walletId: testWalletAId,
        walletName: 'Wallet A',
      );
      final notifB = WalletNotification(
        id: 'notif_b',
        title: 'Wallet B alert',
        message: 'Backup required.',
        category: NotificationCategory.backup,
        createdAt: DateTime(2026, 1, 2),
        walletId: testWalletBId,
        walletName: 'Wallet B',
        action: NotificationAction.backup,
      );
      final systemNotif = WalletNotification(
        id: 'notif_sys',
        title: 'System update',
        message: 'Network status normal.',
        category: NotificationCategory.system,
        createdAt: DateTime(2026, 1, 3),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(notificationsProvider.notifier);
      await notifier.addNotification(notifA);
      await notifier.addNotification(notifB);
      await notifier.addNotification(systemNotif);

      expect(container.read(notificationsProvider).length, 3);

      // Delete Wallet B
      await notifier.removeNotificationsForWallet(testWalletBId);

      final remaining = container.read(notificationsProvider);
      expect(remaining.length, 2);
      expect(remaining.any((n) => n.id == 'notif_b'), isFalse);
      expect(remaining.any((n) => n.id == 'notif_a'), isTrue);
      expect(remaining.any((n) => n.id == 'notif_sys'), isTrue);
    });
  });

  group('Storage Corruption Handling & Quarantine (Requirement 10)', () {
    test('quarantines non-list JSON and resets to safe empty list', () async {
      await prefs.setString(
        'root_wallet_notifications_v1',
        jsonEncode({'invalid': 'structure'}),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final items = container.read(notificationsProvider);
      expect(items, isEmpty);
      expect(prefs.containsKey('root_wallet_notifications_v1'), isFalse);
      expect(prefs.getString('root_wallet_notifications_corrupt'), contains('invalid'));
    });

    test('quarantines unparseable string and resets to safe empty list', () async {
      await prefs.setString(
        'root_wallet_notifications_v1',
        '{not valid json at all...',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final items = container.read(notificationsProvider);
      expect(items, isEmpty);
      expect(prefs.containsKey('root_wallet_notifications_v1'), isFalse);
      expect(prefs.getString('root_wallet_notifications_corrupt'), '{not valid json at all...');
    });

    test('gracefully skips single corrupt item in valid JSON list', () async {
      final validNotif = WalletNotification(
        id: 'valid_1',
        title: 'Valid',
        message: 'Valid message',
        category: NotificationCategory.system,
        createdAt: DateTime(2026, 1, 1),
      );

      final listWithCorruptedElement = [
        validNotif.toJson(),
        {'id': 'bad_item', 'corrupt': true}, // missing title, category, etc.
      ];

      await prefs.setString(
        'root_wallet_notifications_v1',
        jsonEncode(listWithCorruptedElement),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
        ],
      );
      addTearDown(container.dispose);

      final items = container.read(notificationsProvider);
      expect(items.length, 1);
      expect(items.first.id, 'valid_1');
    });
  });

  group('Typed NotificationAction (Requirements 15, 16)', () {
    test('tryParse parses valid actions and rejects unknown/malicious routes', () {
      expect(NotificationAction.tryParse('security'), NotificationAction.security);
      expect(NotificationAction.tryParse('connectionRouting'), NotificationAction.connectionRouting);
      expect(NotificationAction.tryParse('backup'), NotificationAction.backup);
      expect(NotificationAction.tryParse(null), isNull);
      expect(NotificationAction.tryParse('/arbitrary/route'), isNull);
      expect(NotificationAction.tryParse('javascript:void(0)'), isNull);
    });
  });

  group('Storage Failure Rollback (Requirements 8, 9)', () {
    test('rolls back in-memory state when persistence write fails', () async {
      final initialNotif = WalletNotification(
        id: 'initial_notif',
        title: 'Initial',
        message: 'Initial message',
        category: NotificationCategory.system,
        createdAt: DateTime(2026, 1, 1),
        isRead: false,
      );

      final failingPrefs = _FailingSharedPreferences({
        'root_wallet_notifications_v1': jsonEncode([initialNotif.toJson()]),
      });

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => failingPrefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(notificationsProvider.notifier);
      expect(container.read(notificationsProvider).length, 1);
      expect(container.read(notificationsProvider).first.isRead, isFalse);

      // 1. addNotification fails and rolls back
      final newNotif = WalletNotification(
        id: 'new_notif',
        title: 'New',
        message: 'New message',
        category: NotificationCategory.wallet,
        createdAt: DateTime(2026, 1, 2),
      );
      final addResult = await notifier.addNotification(newNotif);
      expect(addResult, isFalse);
      expect(container.read(notificationsProvider).length, 1);
      expect(container.read(notificationsProvider).any((n) => n.id == 'new_notif'), isFalse);

      // 2. markAsRead fails and rolls back
      final markResult = await notifier.markAsRead('initial_notif');
      expect(markResult, isFalse);
      expect(container.read(notificationsProvider).first.isRead, isFalse);

      // 3. markAllAsRead fails and rolls back
      final markAllResult = await notifier.markAllAsRead();
      expect(markAllResult, isFalse);
      expect(container.read(notificationsProvider).first.isRead, isFalse);

      // 4. removeNotification fails and rolls back
      final removeResult = await notifier.removeNotification('initial_notif');
      expect(removeResult, isFalse);
      expect(container.read(notificationsProvider).length, 1);

      // 5. clearAll fails and rolls back
      final clearResult = await notifier.clearAll();
      expect(clearResult, isFalse);
      expect(container.read(notificationsProvider).length, 1);
    });
  });
}

class _FailingSharedPreferences implements SharedPreferences {
  _FailingSharedPreferences(this._data);
  final Map<String, Object> _data;

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<bool> setString(String key, String value) async => false;

  @override
  bool containsKey(String key) => _data.containsKey(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
