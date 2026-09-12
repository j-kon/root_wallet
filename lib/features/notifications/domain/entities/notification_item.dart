import 'package:flutter/foundation.dart';
import 'package:root_wallet/features/wallet/domain/entities/wallet_record.dart';

/// Categories of notifications in Root Wallet.
enum NotificationCategory {
  transaction,
  security,
  backup,
  sync,
  wallet,
  system;

  String get label => switch (this) {
        NotificationCategory.transaction => 'Activity',
        NotificationCategory.security => 'Security',
        NotificationCategory.backup => 'Backup',
        NotificationCategory.sync => 'Sync',
        NotificationCategory.wallet => 'Wallet',
        NotificationCategory.system => 'System',
      };
}

/// Typed safe actions for in-app navigation from notifications.
enum NotificationAction {
  security,
  connectionRouting,
  backup;

  static NotificationAction? tryParse(String? value) {
    if (value == null) return null;
    for (final action in NotificationAction.values) {
      if (action.name == value) return action;
    }
    return null;
  }
}

/// A validated, immutable local notification item.
@immutable
class WalletNotification {
  WalletNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.walletId,
    this.walletName,
    this.isRead = false,
    this.action,
  }) {
    validate(
      id: id,
      title: title,
      message: message,
      category: category,
      createdAt: createdAt,
      walletId: walletId,
      walletName: walletName,
      action: action,
    );
  }

  final String id;
  final String? walletId;
  final String? walletName;
  final NotificationCategory category;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final NotificationAction? action;

  DateTime get timestamp => createdAt;

  static void validate({
    required String id,
    required String title,
    required String message,
    required NotificationCategory category,
    required DateTime createdAt,
    String? walletId,
    String? walletName,
    NotificationAction? action,
  }) {
    if (id.trim().isEmpty || id.length > 128) {
      throw const FormatException(
        'Invalid notification ID: must be non-empty and at most 128 characters.',
      );
    }
    if (title.trim().isEmpty || title.length > 256) {
      throw const FormatException(
        'Invalid notification title: must be non-empty and at most 256 characters.',
      );
    }
    if (message.length > 1024) {
      throw const FormatException(
        'Invalid notification message: exceeds maximum length of 1024 characters.',
      );
    }
    if (walletName != null) {
      if (walletName.trim().isEmpty || walletName.length > 128) {
        throw const FormatException(
          'Invalid notification walletName: must be non-empty and at most 128 characters.',
        );
      }
      if (walletId == null) {
        throw const FormatException(
          'Invalid notification: walletName supplied without a valid walletId.',
        );
      }
    }
    if (walletId != null) {
      WalletRecord.validateWalletId(walletId);
    }
    if (action == NotificationAction.backup && walletId == null) {
      throw const FormatException(
        'Invalid notification: backup action requires a non-null walletId.',
      );
    }
  }

  /// Safe generator for recovery-phrase backup reminders that respects watch-only status.
  static WalletNotification? createBackupReminder({
    required WalletRecord wallet,
    String? customId,
  }) {
    if (wallet.isWatchOnly) {
      return null;
    }
    return WalletNotification(
      id: customId ?? 'backup_reminder_${wallet.id}',
      title: 'Secure your recovery phrase',
      message:
          'Back up your 12-word seed phrase and verify it to protect your wallet from permanent data loss.',
      category: NotificationCategory.backup,
      createdAt: DateTime.now(),
      walletId: wallet.id,
      walletName: wallet.name,
      action: NotificationAction.backup,
    );
  }

  WalletNotification copyWith({
    String? id,
    String? walletId,
    String? walletName,
    NotificationCategory? category,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    NotificationAction? action,
  }) {
    return WalletNotification(
      id: id ?? this.id,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      category: category ?? this.category,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      action: action ?? this.action,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (walletId != null) 'walletId': walletId,
      if (walletName != null) 'walletName': walletName,
      'category': category.name,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      if (action != null) 'action': action!.name,
    };
  }

  factory WalletNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String) {
      throw const FormatException('Invalid or missing notification "id".');
    }

    final title = json['title'];
    if (title is! String) {
      throw const FormatException('Invalid or missing notification "title".');
    }

    final message = json['message'];
    if (message is! String) {
      throw const FormatException('Invalid or missing notification "message".');
    }

    final isRead = json['isRead'];
    if (isRead is! bool) {
      throw const FormatException('Invalid or missing notification "isRead" boolean.');
    }

    final categoryStr = json['category'];
    if (categoryStr is! String) {
      throw const FormatException('Invalid or missing notification "category".');
    }
    final category = NotificationCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => throw FormatException('Unsupported category "$categoryStr".'),
    );

    final createdAtRaw = json['createdAt'];
    if (createdAtRaw is! String) {
      throw const FormatException('Invalid or missing notification "createdAt".');
    }
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw FormatException('Malformed createdAt ISO timestamp: "$createdAtRaw".');
    }

    final walletId = json['walletId'] as String?;
    final walletName = json['walletName'] as String?;

    final actionRaw = json['action'];
    final action = actionRaw is String ? NotificationAction.tryParse(actionRaw) : null;

    return WalletNotification(
      id: id,
      title: title,
      message: message,
      category: category,
      createdAt: createdAt,
      walletId: walletId,
      walletName: walletName,
      isRead: isRead,
      action: action,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          walletId == other.walletId &&
          walletName == other.walletName &&
          title == other.title &&
          message == other.message &&
          category == other.category &&
          createdAt == other.createdAt &&
          isRead == other.isRead &&
          action == other.action;

  @override
  int get hashCode => Object.hash(
        id,
        walletId,
        walletName,
        title,
        message,
        category,
        createdAt,
        isRead,
        action,
      );
}

/// Backwards compatibility alias for code using NotificationItem.
typedef NotificationItem = WalletNotification;
