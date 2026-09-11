import 'package:flutter/foundation.dart';

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

/// A product notification item.
@immutable
class WalletNotification {
  const WalletNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.walletId,
    this.walletName,
    this.isRead = false,
    this.routeTarget,
  });

  final String id;
  final String? walletId;
  final String? walletName;
  final NotificationCategory category;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? routeTarget;

  DateTime get timestamp => createdAt;

  WalletNotification copyWith({
    String? id,
    String? walletId,
    String? walletName,
    NotificationCategory? category,
    String? title,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    String? routeTarget,
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
      routeTarget: routeTarget ?? this.routeTarget,
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
      if (routeTarget != null) 'routeTarget': routeTarget,
    };
  }

  factory WalletNotification.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category'] as String? ?? 'system';
    final category = NotificationCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => NotificationCategory.system,
    );

    return WalletNotification(
      id: json['id'] as String,
      walletId: json['walletId'] as String?,
      walletName: json['walletName'] as String?,
      category: category,
      title: json['title'] as String,
      message: json['message'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      routeTarget: json['routeTarget'] as String?,
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
          routeTarget == other.routeTarget;

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
        routeTarget,
      );
}

/// Backwards compatibility alias for code using NotificationItem.
typedef NotificationItem = WalletNotification;
