import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          GlassSurface(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            tint: AppColors.glassSurfaceStrongOf(
              context,
            ).withValues(alpha: AppColors.isDark(context) ? 0.62 : 0.95),
            highlightOpacity: 0.05,
            padding: EdgeInsets.all(
              context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -34,
                  right: -20,
                  child: _AboutOrb(
                    size: 140,
                    color: AppColors.primary.withValues(alpha: 0.18),
                  ),
                ),
                Positioned(
                  bottom: -40,
                  left: -34,
                  child: _AboutOrb(
                    size: 110,
                    color: AppColors.accent.withValues(alpha: 0.12),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'A self-custody Flutter wallet focused on clarity, trust, and secure local control.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        const _AboutBadge(
                          icon: Icons.layers_outlined,
                          label: 'Feature-first architecture',
                        ),
                        const _AboutBadge(
                          icon: Icons.hub_outlined,
                          label: 'Riverpod state management',
                        ),
                        _AboutBadge(
                          icon: Icons.language_rounded,
                          label: env.isProduction
                              ? 'Production flavor'
                              : 'Development flavor',
                        ),
                        const _AboutBadge(
                          icon: Icons.tag_rounded,
                          label:
                              'Version ${AppConstants.appVersionName}+${AppConstants.appBuildNumber}',
                        ),
                      ],
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
          GlassSurface(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            tint: AppColors.glassSurfaceOf(
              context,
            ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.95),
            highlightOpacity: 0.05,
            padding: const EdgeInsets.all(AppSpacing.md),
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
                if (context.isCompactWidth) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copySupport(context),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy support URL'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openSupport(context, ref),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open support'),
                    ),
                  ),
                ] else
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
                          onPressed: () => _openSupport(context, ref),
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

  Future<void> _openSupport(BuildContext context, WidgetRef ref) async {
    final uri = Uri.parse(AppConstants.supportUrl);
    final launched = await ref
        .read(urlLauncherServiceProvider)
        .openExternalUrl(uri);
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
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.95),
      highlightOpacity: 0.05,
      padding: const EdgeInsets.all(AppSpacing.md),
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
    final maxWidth = context.isVeryCompactWidth
        ? 184.0
        : context.isCompactWidth
        ? 224.0
        : 260.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        tint: AppColors.glassSurfaceOf(
          context,
        ).withValues(alpha: AppColors.isDark(context) ? 0.52 : 0.88),
        borderColor: AppColors.glassBorderOf(context).withValues(alpha: 0.72),
        shadowColor: Colors.transparent,
        highlightOpacity: 0.03,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryOf(context)),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w600,
                  fontSize: context.isVeryCompactWidth ? 11.5 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutOrb extends StatelessWidget {
  const _AboutOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
