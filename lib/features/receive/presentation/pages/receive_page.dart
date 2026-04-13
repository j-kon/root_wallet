import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';
import 'package:root_wallet/core/widgets/info_banner.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/receive/presentation/widgets/address_qr.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

class ReceivePage extends ConsumerWidget {
  const ReceivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletControllerProvider);
    final border = AppColors.borderOf(context);
    final surfaceRaised = AppColors.surfaceRaisedOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);

    return AppScaffold(
      title: 'Receive',
      body: walletState.when(
        loading: () => const Loading(label: 'Preparing receive address...'),
        error: (error, stackTrace) => const EmptyState(
          title: 'Address unavailable',
          message: 'We could not load a receive address right now.',
          icon: Icons.qr_code_2_outlined,
        ),
        data: (data) {
          final address = data.receiveAddress;
          final paymentUri = 'bitcoin:$address';

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
                ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.92),
                highlightOpacity: 0.05,
                padding: EdgeInsets.all(
                  context.isCompactWidth ? AppSpacing.md : AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: const [
                        _ReceiveBadge(
                          icon: Icons.language_rounded,
                          label: 'Testnet',
                        ),
                        _ReceiveBadge(
                          icon: Icons.qr_code_2_rounded,
                          label: 'QR ready',
                        ),
                        _ReceiveBadge(
                          icon: Icons.lock_outline_rounded,
                          label: 'Self-custody',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Request bitcoin with a cleaner handoff.',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Share the QR code or copy the address. Only testnet BTC should be sent here.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AddressQr(address: address),
              const SizedBox(height: AppSpacing.md),
              GlassSurface(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                tint: AppColors.glassSurfaceOf(
                  context,
                ).withValues(alpha: AppColors.isDark(context) ? 0.58 : 0.94),
                highlightOpacity: 0.05,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receive address',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Share the full address only with the sender you trust.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: surfaceRaised,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppFormatters.maskAddress(address),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          SelectableText(
                            address,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final useSingleColumn = constraints.maxWidth < 340;
                        final useTwoRowLayout = constraints.maxWidth < 560;

                        if (useSingleColumn) {
                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _copyValue(
                                    context,
                                    address,
                                    'Address copied.',
                                  ),
                                  icon: const Icon(Icons.copy_rounded),
                                  label: const Text('Copy address'),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: () => _copyValue(
                                    context,
                                    paymentUri,
                                    'Payment URI copied.',
                                  ),
                                  icon: const Icon(Icons.link_rounded),
                                  label: const Text('Copy URI'),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _showShareOptions(
                                    context,
                                    ref: ref,
                                    address: address,
                                    paymentUri: paymentUri,
                                  ),
                                  icon: const Icon(Icons.share_outlined),
                                  label: const Text('Share'),
                                ),
                              ),
                            ],
                          );
                        }

                        if (!useTwoRowLayout) {
                          return Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _copyValue(
                                    context,
                                    address,
                                    'Address copied.',
                                  ),
                                  icon: const Icon(Icons.copy_rounded),
                                  label: const Text('Copy address'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _copyValue(
                                    context,
                                    paymentUri,
                                    'Payment URI copied.',
                                  ),
                                  icon: const Icon(Icons.link_rounded),
                                  label: const Text('Copy URI'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _showShareOptions(
                                    context,
                                    ref: ref,
                                    address: address,
                                    paymentUri: paymentUri,
                                  ),
                                  icon: const Icon(Icons.share_outlined),
                                  label: const Text('Share'),
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _copyValue(
                                      context,
                                      address,
                                      'Address copied.',
                                    ),
                                    icon: const Icon(Icons.copy_rounded),
                                    label: const Text('Copy address'),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _copyValue(
                                      context,
                                      paymentUri,
                                      'Payment URI copied.',
                                    ),
                                    icon: const Icon(Icons.link_rounded),
                                    label: const Text('Copy URI'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonalIcon(
                                onPressed: () => _showShareOptions(
                                  context,
                                  ref: ref,
                                  address: address,
                                  paymentUri: paymentUri,
                                ),
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('Share'),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const InfoBanner(
                type: InfoBannerType.warning,
                message:
                    'Only send BTC on testnet to this address. Mainnet transactions are not recoverable here.',
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(height: AppSpacing.sm),
              const InfoBanner(
                type: InfoBannerType.info,
                message:
                    'If you are sharing this as a payment request, copying the URI is more reliable than sending only a screenshot.',
                icon: Icons.info_outline_rounded,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _copyValue(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showShareOptions(
    BuildContext context, {
    required WidgetRef ref,
    required String address,
    required String paymentUri,
  }) async {
    final parentContext = context;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share address'),
                subtitle: const Text(
                  'Open the native share sheet with the address.',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  final shared = await ref.read(shareServiceProvider).shareText(
                        address,
                        subject: 'Root Wallet testnet address',
                      );
                  if (shared || !parentContext.mounted) {
                    return;
                  }
                  await _copyValue(parentContext, address, 'Address copied.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_rounded),
                title: const Text('Share payment request'),
                subtitle: const Text(
                  'Share the bitcoin: URI through the native share sheet.',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  final shared = await ref.read(shareServiceProvider).shareText(
                        paymentUri,
                        subject: 'Root Wallet payment request',
                      );
                  if (shared || !parentContext.mounted) {
                    return;
                  }
                  await _copyValue(
                    parentContext,
                    paymentUri,
                    'Payment URI copied.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copy address'),
                subtitle: const Text('Share the raw testnet address.'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _copyValue(parentContext, address, 'Address copied.');
                },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Copy payment URI'),
                subtitle: const Text(
                  'Includes the bitcoin: prefix for requests.',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _copyValue(
                    parentContext,
                    paymentUri,
                    'Payment URI copied.',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Open payment request'),
                subtitle: const Text(
                  'Open the bitcoin URI in another app if your device supports it.',
                ),
                onTap: () async {
                  Navigator.of(context).pop();
                  final uri = Uri.parse(paymentUri);
                  final launched = await ref
                      .read(urlLauncherServiceProvider)
                      .openExternalUrl(uri);
                  if (launched || !parentContext.mounted) {
                    return;
                  }
                  await _copyValue(
                    parentContext,
                    paymentUri,
                    'Payment URI copied.',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReceiveBadge extends StatelessWidget {
  const _ReceiveBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
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
        highlightOpacity: 0.03,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textPrimary,
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
