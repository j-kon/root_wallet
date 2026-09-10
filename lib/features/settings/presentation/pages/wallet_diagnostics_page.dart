import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/date_time.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class WalletDiagnosticsPage extends ConsumerWidget {
  const WalletDiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostics = ref.watch(walletDiagnosticsControllerProvider);
    final controller = ref.read(walletDiagnosticsControllerProvider.notifier);
    final env = ref.watch(appEnvProvider);
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: 'Diagnostics',
      actions: [
        IconButton(
          tooltip: 'Refresh diagnostics',
          onPressed: diagnostics.isLoading
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  controller.refresh();
                },
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
              RootSpacing.md,
              context.pageHorizontalPadding,
              context.contentBottomSpacing,
            ),
            children: [
              // 1. Solid Diagnostics Health Header Card
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? RootBrandColors.nightPine
                      : RootBrandColors.pureWhite,
                  borderRadius: BorderRadius.circular(RootRadius.lg),
                  border: Border.all(
                    color: isDark
                        ? RootBrandColors.borderPine
                        : const Color(0xFFD7E3DC),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(RootSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                RootBrandColors.pineGreen.withValues(alpha: 0.14),
                            borderRadius:
                                BorderRadius.circular(RootRadius.md),
                            border: Border.all(
                              color: RootBrandColors.pineGreen
                                  .withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(
                            Icons.health_and_safety_outlined,
                            size: 22,
                            color: RootBrandColors.pineGreen,
                          ),
                        ),
                        const SizedBox(width: RootSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wallet health diagnostics',
                                style: TextStyle(
                                  color: isDark
                                      ? RootBrandColors.warmIvory
                                      : RootBrandColors.charcoalPine,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Technical context for debugging sync, cache, and backend behavior without exposing secrets.',
                                style: TextStyle(
                                  color: isDark
                                      ? RootBrandColors.mutedSage
                                      : const Color(0xFF5E6F68),
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: RootSpacing.md),
                    Wrap(
                      spacing: RootSpacing.xs,
                      runSpacing: RootSpacing.xs,
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

              const SizedBox(height: RootSpacing.md),

              // 2. Network and Backend Panel
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
                    value: data.diagnostics.customEsploraEndpoint ??
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

              const SizedBox(height: RootSpacing.md),

              // 3. Wallet Storage and Cache Panel
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
                    label: 'Wallet script type',
                    value: data.diagnostics.scriptType,
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

              const SizedBox(height: RootSpacing.md),

              // 4. Action Buttons (Copy & Rotate)
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 520;
                  final copyButton = MagneticPressable(
                    onTap: () => _copyDiagnostics(context, data),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? RootBrandColors.slatePine
                            : const Color(0xFFE8EFEA),
                        borderRadius: BorderRadius.circular(RootRadius.md),
                        border: Border.all(
                          color: isDark
                              ? RootBrandColors.borderPine
                              : const Color(0xFFD7E3DC),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 16,
                            color: isDark
                                ? RootBrandColors.warmIvory
                                : RootBrandColors.charcoalPine,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Copy diagnostics',
                            style: TextStyle(
                              color: isDark
                                  ? RootBrandColors.warmIvory
                                  : RootBrandColors.charcoalPine,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  final backendButton = MagneticPressable(
                    onTap: canRotateBackend
                        ? () async {
                            HapticFeedback.lightImpact();
                            await controller.tryNextBackend();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Backend rotation requested.'),
                              ),
                            );
                          }
                        : null,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: canRotateBackend
                            ? RootBrandColors.pineGreen
                            : (isDark
                                ? const Color(0xFF192522)
                                : const Color(0xFFE2E8E4)),
                        borderRadius: BorderRadius.circular(RootRadius.md),
                        border: Border.all(
                          color: canRotateBackend
                              ? RootBrandColors.pineGreen
                              : (isDark
                                  ? RootBrandColors.borderPine
                                  : const Color(0xFFD7E3DC)),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.route_rounded,
                            size: 16,
                            color: canRotateBackend
                                ? RootBrandColors.pureWhite
                                : (isDark
                                    ? RootBrandColors.mutedSage
                                    : const Color(0xFF8B9E95)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            canRotateBackend
                                ? 'Try next backend'
                                : 'One backend configured',
                            style: TextStyle(
                              color: canRotateBackend
                                  ? RootBrandColors.pureWhite
                                  : (isDark
                                      ? RootBrandColors.mutedSage
                                      : const Color(0xFF8B9E95)),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        copyButton,
                        const SizedBox(height: RootSpacing.sm),
                        backendButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: copyButton),
                      const SizedBox(width: RootSpacing.sm),
                      Expanded(child: backendButton),
                    ],
                  );
                },
              ),

              if (!env.isProduction) ...[
                const SizedBox(height: RootSpacing.md),
                _DiagnosticsPanel(
                  title: 'Development backend override',
                  subtitle:
                      'Optional local-only override for testing another testnet Esplora endpoint.',
                  children: [
                    _DiagnosticsRow(
                      label: 'Stored override',
                      value: data.diagnostics.customEsploraEndpoint ??
                          'Not set',
                    ),
                    const SizedBox(height: RootSpacing.xs),
                    MagneticPressable(
                      onTap: () => _editCustomEndpoint(
                        context,
                        controller,
                        currentEndpoint:
                            data.diagnostics.customEsploraEndpoint ?? '',
                      ),
                      child: Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? RootBrandColors.slatePine
                              : const Color(0xFFE8EFEA),
                          borderRadius: BorderRadius.circular(RootRadius.md),
                          border: Border.all(
                            color: isDark
                                ? RootBrandColors.borderPine
                                : const Color(0xFFD7E3DC),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: isDark
                                  ? RootBrandColors.warmIvory
                                  : RootBrandColors.charcoalPine,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Set custom endpoint',
                              style: TextStyle(
                                color: isDark
                                    ? RootBrandColors.warmIvory
                                    : RootBrandColors.charcoalPine,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
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
    HapticFeedback.lightImpact();
    const encoder = JsonEncoder.withIndent('  ');
    await Clipboard.setData(
      ClipboardData(text: encoder.convert(data.toJson())),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnostics copied.')),
    );
  }

  Future<void> _editCustomEndpoint(
    BuildContext context,
    WalletDiagnosticsController controller, {
    required String currentEndpoint,
  }) async {
    final endpoint = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => _CustomEndpointDialog(
        currentEndpoint: currentEndpoint,
      ),
    );

    if (endpoint == null || !context.mounted) return;

    try {
      await controller.setCustomBackend(
        endpoint.trim().isEmpty ? null : endpoint.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backend endpoint updated.')),
      );
    } catch (_) {
      if (!context.mounted) return;
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
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(RootSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark
                  ? RootBrandColors.warmIvory
                  : RootBrandColors.charcoalPine,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: RootSpacing.md),
          ...children.expand(
            (child) => <Widget>[child, const SizedBox(height: RootSpacing.sm)],
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
    final isDark = AppColors.isDark(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: RootSpacing.sm),
        Expanded(
          flex: 2,
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isDark
                  ? RootBrandColors.warmIvory
                  : RootBrandColors.charcoalPine,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: value.contains('/') || value.contains(':')
                  ? 'monospace'
                  : null,
            ),
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
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? RootBrandColors.slatePine : const Color(0xFFF0F4F2),
        borderRadius: BorderRadius.circular(RootRadius.pill),
        border: Border.all(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: RootBrandColors.pineGreen),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? RootBrandColors.warmIvory
                  : RootBrandColors.charcoalPine,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomEndpointDialog extends StatefulWidget {
  const _CustomEndpointDialog({required this.currentEndpoint});

  final String currentEndpoint;

  @override
  State<_CustomEndpointDialog> createState() => _CustomEndpointDialogState();
}

class _CustomEndpointDialogState extends State<_CustomEndpointDialog> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentEndpoint);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return AlertDialog(
      backgroundColor:
          isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RootRadius.lg),
        side: BorderSide(
          color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      title: Text(
        'Custom Esplora endpoint',
        style: TextStyle(
          color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: TextField(
        controller: _textController,
        autofocus: true,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        style: TextStyle(
          color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
          fontFamily: 'monospace',
          fontSize: 13,
        ),
        decoration: InputDecoration(
          labelText: 'Endpoint URL',
          hintText: 'https://mempool.space/testnet/api',
          filled: true,
          fillColor: isDark ? RootBrandColors.slatePine : const Color(0xFFF6F8F7),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RootRadius.md),
            borderSide: BorderSide(
              color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RootRadius.md),
            borderSide: BorderSide(
              color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RootRadius.md),
            borderSide: const BorderSide(
              color: RootBrandColors.pineGreen,
              width: 1.5,
            ),
          ),
        ),
        onSubmitted: (_) => Navigator.of(context).pop(_textController.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
            ),
          ),
        ),
        if (widget.currentEndpoint.trim().isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text('Clear'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: RootBrandColors.pineGreen,
          ),
          onPressed: () => Navigator.of(context).pop(_textController.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
