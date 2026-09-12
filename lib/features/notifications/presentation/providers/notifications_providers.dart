import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/features/notifications/domain/entities/notification_item.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';

const int maxNotificationStorageLimit = 200;
const _notificationsStorageKey = 'root_wallet_notifications_v1';
const _corruptNotificationsStorageKey = 'root_wallet_notifications_corrupt';

class NotificationsNotifier extends Notifier<List<WalletNotification>> {
  @override
  List<WalletNotification> build() {
    final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
    if (prefs == null) {
      return const <WalletNotification>[];
    }

    final raw = prefs.getString(_notificationsStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <WalletNotification>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        // Corrupt storage structure: clear active key, quarantine, return empty list
        prefs.remove(_notificationsStorageKey);
        prefs.setString(_corruptNotificationsStorageKey, raw);
        return const <WalletNotification>[];
      }

      final validItems = <WalletNotification>[];
      for (final element in decoded) {
        if (element is Map<String, dynamic>) {
          try {
            validItems.add(WalletNotification.fromJson(element));
          } catch (_) {
            // Malformed individual entry safely skipped
          }
        }
      }

      // Ensure deterministic newest-first sort order
      validItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Enforce storage retention cap
      return validItems.take(maxNotificationStorageLimit).toList();
    } catch (_) {
      // Malformed JSON string: clear active key, quarantine, return empty list
      prefs.remove(_notificationsStorageKey);
      prefs.setString(_corruptNotificationsStorageKey, raw);
      return const <WalletNotification>[];
    }
  }

  Future<bool> _persist(List<WalletNotification> items) async {
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final encoded = jsonEncode(items.map((i) => i.toJson()).toList());
      final success = await prefs.setString(_notificationsStorageKey, encoded);
      return success;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addNotification(WalletNotification item) async {
    final previous = state;

    // Deduplicate: update existing notification if same ID exists, otherwise append
    final list = List<WalletNotification>.from(state);
    final existingIndex = list.indexWhere((n) => n.id == item.id);
    if (existingIndex >= 0) {
      list[existingIndex] = item;
    } else {
      list.add(item);
    }

    // Always keep newest-first sort order
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Enforce retention cap
    final capped = list.take(maxNotificationStorageLimit).toList();

    state = capped;
    final ok = await _persist(capped);
    if (!ok) {
      state = previous;
      return false;
    }
    return true;
  }

  Future<bool> markAsRead(String id) async {
    final previous = state;
    final updated = [
      for (final item in state)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
    state = updated;
    final ok = await _persist(updated);
    if (!ok) {
      state = previous;
      return false;
    }
    return true;
  }

  Future<bool> markAllAsRead() async {
    final previous = state;
    final updated = [
      for (final item in state) item.copyWith(isRead: true),
    ];
    state = updated;
    final ok = await _persist(updated);
    if (!ok) {
      state = previous;
      return false;
    }
    return true;
  }

  Future<bool> removeNotification(String id) async {
    final previous = state;
    final updated = state.where((item) => item.id != id).toList();
    state = updated;
    final ok = await _persist(updated);
    if (!ok) {
      state = previous;
      return false;
    }
    return true;
  }

  Future<bool> removeNotificationsForWallet(String walletId) async {
    final previous = state;
    final updated = state.where((item) => item.walletId != walletId).toList();
    state = updated;
    final ok = await _persist(updated);
    if (!ok) {
      state = previous;
      return false;
    }
    return true;
  }

  Future<bool> clearAll() async {
    final previous = state;
    state = const [];
    final ok = await _persist(const []);
    if (!ok) {
      state = previous;
      return false;
    }
    return true;
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<WalletNotification>>(
  NotificationsNotifier.new,
);

/// Decoy-isolated visible notifications provider.
///
/// When decoy mode is active, returns an empty list to prevent leaking
/// real wallet names, balances, or transaction updates.
final visibleNotificationsProvider = Provider<List<WalletNotification>>((ref) {
  final isDecoy = ref.watch(isDecoyModeProvider);
  if (isDecoy) {
    return const <WalletNotification>[];
  }
  return ref.watch(notificationsProvider);
});

/// Reactive unread count provider that respects decoy privacy.
///
/// In decoy mode, strictly returns 0 so that no unread indicators are exposed.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final isDecoy = ref.watch(isDecoyModeProvider);
  if (isDecoy) {
    return 0;
  }
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});
