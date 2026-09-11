import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/features/notifications/domain/entities/notification_item.dart';

const _notificationsStorageKey = 'root_wallet_notifications_v1';

List<WalletNotification> get _defaultNotifications {
  final now = DateTime.now();
  return [
    WalletNotification(
      id: 'notif_welcome',
      title: 'Wallet ready for testnet',
      message:
          'Your Bitcoin testnet wallet is initialized. You can receive, spend, and manage testnet UTXOs.',
      category: NotificationCategory.wallet,
      createdAt: now.subtract(const Duration(minutes: 15)),
      walletName: 'Main Wallet',
      isRead: false,
    ),
    WalletNotification(
      id: 'notif_backup',
      title: 'Secure your recovery phrase',
      message:
          'Back up your 12-word seed phrase and verify it to protect your wallet from permanent data loss.',
      category: NotificationCategory.security,
      createdAt: now.subtract(const Duration(hours: 2)),
      walletName: 'Main Wallet',
      isRead: false,
      routeTarget: AppRoutes.security,
    ),
    WalletNotification(
      id: 'notif_network',
      title: 'SOCKS5 privacy routing',
      message:
          'Tor-compatible SOCKS5 privacy routing is available in Connection Routing settings.',
      category: NotificationCategory.system,
      createdAt: now.subtract(const Duration(days: 1)),
      isRead: true,
      routeTarget: AppRoutes.connectionRouting,
    ),
  ];
}

class NotificationsNotifier extends Notifier<List<WalletNotification>> {
  @override
  List<WalletNotification> build() {
    final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
    if (prefs != null) {
      final raw = prefs.getString(_notificationsStorageKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw) as List<dynamic>;
          return decoded
              .map((item) =>
                  WalletNotification.fromJson(item as Map<String, dynamic>))
              .toList();
        } catch (_) {
          // Fallback to defaults on corrupted persistence
        }
      }
    }

    // Default seeded notifications
    final defaults = _defaultNotifications;
    return defaults;
  }

  Future<void> _persist(List<WalletNotification> items) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
      await prefs.setString(_notificationsStorageKey, encoded);
    } catch (_) {}
  }

  void markAsRead(String id) {
    final updated = [
      for (final item in state)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
    state = updated;
    _persist(updated);
  }

  void markAllAsRead() {
    final updated = [
      for (final item in state) item.copyWith(isRead: true),
    ];
    state = updated;
    _persist(updated);
  }

  void removeNotification(String id) {
    final updated = state.where((item) => item.id != id).toList();
    state = updated;
    _persist(updated);
  }

  void clearAll() {
    state = const [];
    _persist(const []);
  }

  void addNotification(WalletNotification item) {
    final updated = [item, ...state];
    state = updated;
    _persist(updated);
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<WalletNotification>>(
  NotificationsNotifier.new,
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});
