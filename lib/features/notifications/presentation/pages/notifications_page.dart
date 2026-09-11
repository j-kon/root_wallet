import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/features/notifications/domain/entities/notification_item.dart';
import 'package:root_wallet/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

enum _NotificationFilter { all, unread }

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  _NotificationFilter _filter = _NotificationFilter.all;

  String _formatRelativeTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays == 1) {
      return 'Yesterday';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    return '${timestamp.month}/${timestamp.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final textPrimary =
        isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine;
    final textSecondary =
        isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68);

    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    final filteredList = switch (_filter) {
      _NotificationFilter.all => notifications,
      _NotificationFilter.unread =>
        notifications.where((n) => !n.isRead).toList(),
    };

    return AppScaffold(
      title: 'Notifications',
      actions: [
        if (unreadCount > 0)
          TextButton(
            key: const ValueKey('notifications_mark_all_read_button'),
            onPressed: () {
              HapticFeedback.selectionClick();
              ref.read(notificationsProvider.notifier).markAllAsRead();
            },
            child: const Text(
              'Mark all as read',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: RootBrandColors.pineGreen,
              ),
            ),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter chip row
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.pageHorizontalPadding,
              vertical: RootSpacing.sm,
            ),
            child: Row(
              children: [
                _FilterChip(
                  key: const ValueKey('notifications_filter_all'),
                  label: 'All (${notifications.length})',
                  isSelected: _filter == _NotificationFilter.all,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _filter = _NotificationFilter.all);
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: RootSpacing.xs),
                _FilterChip(
                  key: const ValueKey('notifications_filter_unread'),
                  label: 'Unread ($unreadCount)',
                  isSelected: _filter == _NotificationFilter.unread,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _filter = _NotificationFilter.unread);
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: RootSpacing.xs),

          // List or Empty state
          Expanded(
            child: filteredList.isEmpty
                ? EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: "You're all caught up.",
                    message: _filter == _NotificationFilter.unread
                        ? 'No unread notifications at this time.'
                        : 'Important wallet, security and transaction updates will appear here.',
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      context.pageHorizontalPadding,
                      RootSpacing.xs,
                      context.pageHorizontalPadding,
                      context.contentBottomSpacing,
                    ),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: RootSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return _NotificationCard(
                        key: ValueKey('notification_card_${item.id}'),
                        item: item,
                        formattedTime: _formatRelativeTime(item.createdAt),
                        isDark: isDark,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (!item.isRead) {
                            ref
                                .read(notificationsProvider.notifier)
                                .markAsRead(item.id);
                          }
                          if (item.routeTarget != null) {
                            Navigator.of(context).pushNamed(item.routeTarget!);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isSelected
        ? RootBrandColors.pineGreen
        : (isDark
            ? RootBrandColors.nightPine
            : RootBrandColors.pureWhite);
    final textColor = isSelected
        ? Colors.white
        : (isDark
            ? RootBrandColors.mutedSage
            : const Color(0xFF5E6F68));
    final borderColor = isSelected
        ? RootBrandColors.pineGreen
        : (isDark
            ? RootBrandColors.borderPine
            : const Color(0xFFD7E3DC));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RootRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(RootRadius.pill),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.item,
    required this.formattedTime,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  final WalletNotification item;
  final String formattedTime;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  (IconData, Color, Color) get _categoryStyle {
    switch (item.category) {
      case NotificationCategory.wallet:
        return (
          Icons.account_balance_wallet_rounded,
          RootBrandColors.pineGreen.withValues(alpha: 0.15),
          RootBrandColors.pineGreen,
        );
      case NotificationCategory.security:
        return (
          Icons.shield_outlined,
          RootBrandColors.amberAccent.withValues(alpha: 0.15),
          RootBrandColors.amberAccent,
        );
      case NotificationCategory.backup:
        return (
          Icons.key_rounded,
          RootBrandColors.amberAccent.withValues(alpha: 0.15),
          RootBrandColors.amberAccent,
        );
      case NotificationCategory.transaction:
        return (
          Icons.swap_horiz_rounded,
          RootBrandColors.pineGreen.withValues(alpha: 0.15),
          RootBrandColors.pineGreen,
        );
      case NotificationCategory.sync:
        return (
          Icons.sync_rounded,
          RootBrandColors.pineGreen.withValues(alpha: 0.15),
          RootBrandColors.pineGreen,
        );
      case NotificationCategory.system:
        return (
          Icons.alt_route_rounded,
          (isDark ? RootBrandColors.slatePine : const Color(0xFFE3EDE7)),
          (isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, iconBg, iconColor) = _categoryStyle;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RootRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(RootSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? RootBrandColors.nightPine
              : RootBrandColors.pureWhite,
          borderRadius: BorderRadius.circular(RootRadius.lg),
          border: Border.all(
            color: item.isRead
                ? (isDark
                    ? RootBrandColors.borderPine
                    : const Color(0xFFD7E3DC))
                : RootBrandColors.pineGreen.withValues(alpha: 0.4),
            width: item.isRead ? 1.0 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon Badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(RootRadius.md),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: RootSpacing.sm),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category tag, wallet tag & timestamp row
                  Row(
                    children: [
                      Text(
                        item.category.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark
                              ? RootBrandColors.mutedSage
                              : const Color(0xFF5E6F68),
                        ),
                      ),
                      if (item.walletName != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? RootBrandColors.slatePine
                                : const Color(0xFFE8EFEA),
                            borderRadius: BorderRadius.circular(RootRadius.xs),
                          ),
                          child: Text(
                            item.walletName!,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 10,
                          color: textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: RootBrandColors.amberAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Title
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight:
                          item.isRead ? FontWeight.w600 : FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Message
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: textSecondary,
                    ),
                  ),

                  // Optional action indicator
                  if (item.routeTarget != null) ...[
                    const SizedBox(height: RootSpacing.xs),
                    Row(
                      children: [
                        const Text(
                          'View details',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: RootBrandColors.pineGreen,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: RootBrandColors.pineGreen,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
