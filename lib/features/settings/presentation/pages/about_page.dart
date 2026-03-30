import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);
    final shadow = AppColors.shadowOf(context);
    final env = ref.watch(appEnvProvider);

    return AppScaffold(
      title: 'About',
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          context.pageHorizontalPadding,
          AppSpacing.md,
          context.pageHorizontalPadding,
          context.contentBottomSpacing,
        ),
        children: [
          Container(
            padding: EdgeInsets.all(
              context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.secondary, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A self-custody Flutter wallet focused on clarity, trust, and secure local control.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _AboutBadge(
                      icon: Icons.layers_outlined,
                      label: 'Feature-first architecture',
                    ),
                    _AboutBadge(
                      icon: Icons.hub_outlined,
                      label: 'Riverpod state management',
                    ),
                    _AboutBadge(
                      icon: Icons.language_rounded,
                      label: env.isProduction
                          ? 'Production flavor'
                          : 'Development flavor',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _AboutPanel(
            title: 'Design principles',
            subtitle: 'How the product should behave as it grows.',
            bulletPoints: [
              'Trust first: show network, sync health, and backup posture clearly.',
              'Reduce user doubt: important actions should explain risk before execution.',
              'Keep architecture readable: features, domain logic, and UI state remain separated.',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _AboutPanel(
            title: 'Technical posture',
            subtitle: 'Current implementation direction.',
            bulletPoints: [
              'Local credentials and security controls are handled on-device.',
              'Wallet flows are structured into feature modules and use cases.',
              'The app is currently optimized around Bitcoin testnet workflows.',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Open support in the browser or copy the URL for later.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copySupport(context),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy support URL'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _openSupport(context),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open support'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copySupport(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: AppConstants.supportUrl));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Support URL copied.')));
  }

  Future<void> _openSupport(BuildContext context) async {
    final uri = Uri.parse(AppConstants.supportUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) {
      return;
    }
    await _copySupport(context);
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel({
    required this.title,
    required this.subtitle,
    required this.bulletPoints,
  });

  final String title;
  final String subtitle;
  final List<String> bulletPoints;

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surfaceOf(context);
    final border = AppColors.borderOf(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          for (final point in bulletPoints) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 7, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    point,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (point != bulletPoints.last)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _AboutBadge extends StatelessWidget {
  const _AboutBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
