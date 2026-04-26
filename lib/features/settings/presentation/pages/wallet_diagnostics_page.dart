import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class WalletDiagnosticsPage extends ConsumerWidget {
  const WalletDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostics = ref.watch(walletDiagnosticsControllerProvider);
    final controller = ref.read(walletDiagnosticsControllerProvider.notifier);
    final env = ref.watch(appEnvProvider);

    return AppScaffold(
      title: 'Diagnostics',
      actions: [
        IconButton(
          tooltip: 'Refresh diagnostics',
          onPressed: diagnostics.isLoading ? null : controller.refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: diagnostics.when(
        loading: () => const Loading(label: 'Loading diagnostics...'),
        error: (error, stackTrace) => EmptyState(
          title: 'Diagnostics unavailable',
          message: 'Could not load wallet diagnostics right now.',
          actionLabel: 'Retry',
          onAction: controller.refresh,
          icon: Icons.health_and_safety_outlined,
        ),
        data: (data) {
          final configuredCount =
              data.diagnostics.configuredEsploraEndpoints.length;
          final canRotateBackend = configuredCount > 1;

          return ListView(
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
                ).withValues(alpha: AppColors.isDark(context) ? 0.62 : 0.96),
                highlightOpacity: 0.05,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wallet health diagnostics',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Technical context for debugging sync, cache, and backend behavior without exposing secrets.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryOf(context),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _DiagnosticsChip(
                          icon: Icons.language_rounded,
                          label: data.diagnostics.networkLabel,
                        ),
                        _DiagnosticsChip(
                          icon: Icons.storage_rounded,
                          label: data.diagnostics.walletExists
                              ? 'Wallet found'
                              : 'No wallet',
                        ),
                        _DiagnosticsChip(
                          icon: Icons.cached_rounded,
                          label: data.cacheUpdatedAt == null
                              ? 'No cache'
                              : 'Cache ${AppDateTime.updatedAgo(data.cacheUpdatedAt!)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _DiagnosticsPanel(
                title: 'Network and backend',
                subtitle:
                    'The public Bitcoin testnet connection currently in use.',
                children: [
                  _DiagnosticsRow(
                    label: 'App network label',
                    value: data.diagnostics.networkLabel,
                  ),
                  _DiagnosticsRow(
                    label: 'BDK network family',
                    value: data.diagnostics.bdkNetwork,
                  ),
                  _DiagnosticsRow(
                    label: 'Active Esplora endpoint',
                    value: data.diagnostics.activeEsploraEndpoint,
                  ),
                  _DiagnosticsRow(
                    label: 'Configured endpoints',
                    value: '$configuredCount',
                  ),
                  _DiagnosticsRow(
                    label: 'Failover state',
                    value: data.diagnostics.backendFailoverState,
                  ),
                  _DiagnosticsRow(
                    label: 'Last backend failure',
                    value: data.diagnostics.lastBackendFailure ?? 'None',
                  ),
                  _DiagnosticsRow(
                    label: 'Last failure time',
                    value: data.diagnostics.lastBackendFailureAt == null
                        ? 'None'
                        : AppDateTime.ymdHm(
                            data.diagnostics.lastBackendFailureAt!,
                          ),
                  ),
                  _DiagnosticsRow(
                    label: 'Custom dev endpoint',
                    value:
                        data.diagnostics.customEsploraEndpoint ??
                        (env.isProduction
                            ? 'Disabled in production'
                            : 'Not set'),
                  ),
                  _DiagnosticsRow(
                    label: 'Explorer base URL',
                    value: AppConstants.testnetExplorerBaseUrl,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _DiagnosticsPanel(
                title: 'Wallet storage and cache',
                subtitle:
                    'Local state used for offline fallback and wallet DB access.',
                children: [
                  _DiagnosticsRow(
                    label: 'Wallet database path',
                    value: data.diagnostics.walletDatabasePath,
                  ),
                  _DiagnosticsRow(
                    label: 'Wallet exists',
                    value: data.diagnostics.walletExists ? 'Yes' : 'No',
                  ),
                  _DiagnosticsRow(
                    label: 'Cache updated',
                    value: data.cacheUpdatedAt == null
                        ? 'No cached snapshot'
                        : AppDateTime.ymdHm(data.cacheUpdatedAt!),
                  ),
                  _DiagnosticsRow(
                    label: 'Cached transactions',
                    value: '${data.cacheTransactionCount}',
                  ),
                  _DiagnosticsRow(
                    label: 'Wallet state',
                    value: data.walletStateLabel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 520;
                  final copyButton = OutlinedButton.icon(
                    onPressed: () => _copyDiagnostics(context, data),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy diagnostics'),
                  );
                  final backendButton = FilledButton.tonalIcon(
                    onPressed: canRotateBackend
                        ? () async {
                            await controller.tryNextBackend();
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Backend rotation requested.'),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.route_rounded),
                    label: Text(
                      canRotateBackend
                          ? 'Try next backend'
                          : 'One backend configured',
                    ),
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        SizedBox(width: double.infinity, child: copyButton),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(width: double.infinity, child: backendButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: copyButton),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: backendButton),
                    ],
                  );
                },
              ),
              if (!env.isProduction) ...[
                const SizedBox(height: AppSpacing.md),
                _DiagnosticsPanel(
                  title: 'Development backend override',
                  subtitle:
                      'Optional local-only override for testing another testnet Esplora endpoint.',
                  children: [
                    _DiagnosticsRow(
                      label: 'Stored override',
                      value:
                          data.diagnostics.customEsploraEndpoint ?? 'Not set',
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _editCustomEndpoint(
                          context,
                          controller,
                          currentEndpoint:
                              data.diagnostics.customEsploraEndpoint ?? '',
                        ),
                        icon: const Icon(Icons.tune_rounded),
                        label: const Text('Set custom endpoint'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _copyDiagnostics(
    BuildContext context,
    WalletDiagnosticsState data,
  ) async {
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(
      ClipboardData(text: encoder.convert(data.toJson())),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Diagnostics copied.')));
  }

  Future<void> _editCustomEndpoint(
    BuildContext context,
    WalletDiagnosticsController controller, {
    required String currentEndpoint,
  }) async {
    final textController = TextEditingController(text: currentEndpoint);
    final endpoint = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom Esplora endpoint'),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Endpoint URL',
            hintText: 'https://mempool.space/testnet/api',
          ),
          onSubmitted: (_) =>
              Navigator.of(dialogContext).pop(textController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancel'),
          ),
          if (currentEndpoint.trim().isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Clear'),
            ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    textController.dispose();

    if (endpoint == null || !context.mounted) {
      return;
    }

    try {
      await controller.setCustomBackend(
        endpoint.trim().isEmpty ? null : endpoint.trim(),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backend endpoint updated.')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Endpoint not saved. Check the URL and try again.'),
        ),
      );
    }
  }
}

class _DiagnosticsPanel extends StatelessWidget {
  const _DiagnosticsPanel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.68 : 0.97),
      highlightOpacity: 0.05,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryOf(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children.expand(
            (child) => <Widget>[child, const SizedBox(height: AppSpacing.sm)],
          ),
        ]..removeLast(),
      ),
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppColors.textSecondaryOf(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticsChip extends StatelessWidget {
  const _DiagnosticsChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      tint: AppColors.glassSurfaceOf(
        context,
      ).withValues(alpha: AppColors.isDark(context) ? 0.52 : 0.88),
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
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
