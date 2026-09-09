import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/di/providers.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/constants/app_constants.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/empty_state.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/features/receive/presentation/widgets/address_qr.dart';
import 'package:root_wallet/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:root_wallet/shared/extensions/context_x.dart';

/// Redesigned Receive Page adhering strictly to Root Wallet Brand Guidelines.
/// Features a solid-surface layout, dynamic BIP-21 amount requests,
/// chunked monospace address presentation, and high-trust Bitcoin standards.
class ReceivePage extends ConsumerStatefulWidget {
  const ReceivePage({super.key});

  @override
  ConsumerState<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends ConsumerState<ReceivePage> {
  bool _isRequestExpanded = false;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double? get _parsedAmountBtc {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  String _buildPaymentUri(String address) {
    final btc = _parsedAmountBtc;
    final note = _noteController.text.trim();
    final queryParams = <String>[];

    if (btc != null && btc > 0) {
      queryParams.add(
        'amount=${btc.toStringAsFixed(8).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}',
      );
    }
    if (note.isNotEmpty) {
      queryParams.add('label=${Uri.encodeComponent(note)}');
    }

    if (queryParams.isEmpty) {
      return 'bitcoin:$address';
    }
    return 'bitcoin:$address?${queryParams.join('&')}';
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletControllerProvider);
    final isDark = AppColors.isDark(context);

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
          final addressLabel =
              ref
                  .watch(walletLabelsControllerProvider)
                  .valueOrNull
                  ?.addressLabel(address) ??
              '';
          final paymentUri = _buildPaymentUri(address);
          final networkName = AppConstants.networkDisplayName;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              context.pageHorizontalPadding,
              RootSpacing.md,
              context.pageHorizontalPadding,
              context.contentBottomSpacing + RootSpacing.xl,
            ),
            children: [
              // 1. Bitcoin Network & Standard Badge Card
              _NetworkOverviewCard(isDark: isDark, networkName: networkName),
              const SizedBox(height: RootSpacing.md),

              // 2. High-Contrast QR Code Card
              AddressQr(
                address: address,
                payload: paymentUri,
                requestedAmountBtc: _parsedAmountBtc,
              ),
              const SizedBox(height: RootSpacing.md),

              // 3. Receive Address Card
              _ReceiveAddressCard(
                isDark: isDark,
                address: address,
                addressLabel: addressLabel,
                paymentUri: paymentUri,
                onCopyAddress: () => _copyValue(
                  context,
                  address,
                  'Address copied to clipboard.',
                ),
                onCopyUri: () =>
                    _copyValue(context, paymentUri, 'Payment URI copied.'),
                onShare: () => _showShareOptions(
                  context,
                  ref: ref,
                  address: address,
                  paymentUri: paymentUri,
                ),
                onEditLabel: () => _editAddressLabel(
                  context,
                  ref,
                  address: address,
                  currentLabel: addressLabel,
                ),
              ),
              const SizedBox(height: RootSpacing.md),

              // 4. BIP-21 Amount Request Expander Card
              _Bip21RequestCard(
                isDark: isDark,
                isExpanded: _isRequestExpanded,
                amountController: _amountController,
                noteController: _noteController,
                hasCustomAmount:
                    _parsedAmountBtc != null && _parsedAmountBtc! > 0,
                onToggleExpand: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isRequestExpanded = !_isRequestExpanded;
                  });
                },
                onClear: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _amountController.clear();
                    _noteController.clear();
                  });
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: RootSpacing.md),

              // 5. Technical Details & Security Advice Card
              _AddressDetailsCard(isDark: isDark, networkName: networkName),
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
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editAddressLabel(
    BuildContext context,
    WidgetRef ref, {
    required String address,
    required String currentLabel,
  }) async {
    HapticFeedback.selectionClick();
    final isDark = AppColors.isDark(context);

    final label = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => _LabelReceiveAddressDialog(
        currentLabel: currentLabel,
        isDark: isDark,
      ),
    );

    if (label == null || !context.mounted) {
      return;
    }

    await ref
        .read(walletLabelsControllerProvider.notifier)
        .setAddressLabel(address, label);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Address label saved.')));
  }

  Future<void> _showShareOptions(
    BuildContext context, {
    required WidgetRef ref,
    required String address,
    required String paymentUri,
  }) async {
    HapticFeedback.selectionClick();
    final parentContext = context;
    final isDark = AppColors.isDark(context);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: isDark
          ? RootBrandColors.nightPine
          : RootBrandColors.pureWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RootRadius.xl),
        ),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: RootSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RootSpacing.lg,
                    vertical: RootSpacing.xs,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Share Receive Options',
                      style: TextStyle(
                        color: isDark
                            ? RootBrandColors.warmIvory
                            : RootBrandColors.charcoalPine,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF16382C)
                          : const Color(0xFFE8F3EE),
                      borderRadius: BorderRadius.circular(RootRadius.sm),
                    ),
                    child: const Icon(
                      Icons.share_outlined,
                      size: 20,
                      color: RootBrandColors.pineGreen,
                    ),
                  ),
                  title: const Text('Share address'),
                  subtitle: const Text(
                    'Share the raw Bitcoin testnet address.',
                  ),
                  onTap: () async {
                    Navigator.of(modalContext).pop();
                    final shared = await ref
                        .read(shareServiceProvider)
                        .shareText(
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
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF16382C)
                          : const Color(0xFFE8F3EE),
                      borderRadius: BorderRadius.circular(RootRadius.sm),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 20,
                      color: RootBrandColors.pineGreen,
                    ),
                  ),
                  title: const Text('Share payment request'),
                  subtitle: const Text('Share formatted bitcoin: payment URI.'),
                  onTap: () async {
                    Navigator.of(modalContext).pop();
                    final shared = await ref
                        .read(shareServiceProvider)
                        .shareText(
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
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? RootBrandColors.slatePine
                          : const Color(0xFFEFF5F2),
                      borderRadius: BorderRadius.circular(RootRadius.sm),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 20,
                      color: isDark
                          ? RootBrandColors.mutedSage
                          : const Color(0xFF5E6F68),
                    ),
                  ),
                  title: const Text('Copy address'),
                  subtitle: const Text('Save to device clipboard.'),
                  onTap: () async {
                    Navigator.of(modalContext).pop();
                    await _copyValue(parentContext, address, 'Address copied.');
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? RootBrandColors.slatePine
                          : const Color(0xFFEFF5F2),
                      borderRadius: BorderRadius.circular(RootRadius.sm),
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      size: 20,
                      color: isDark
                          ? RootBrandColors.mutedSage
                          : const Color(0xFF5E6F68),
                    ),
                  ),
                  title: const Text('Copy payment URI'),
                  subtitle: const Text('Includes bitcoin: URI parameters.'),
                  onTap: () async {
                    Navigator.of(modalContext).pop();
                    await _copyValue(
                      parentContext,
                      paymentUri,
                      'Payment URI copied.',
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? RootBrandColors.slatePine
                          : const Color(0xFFEFF5F2),
                      borderRadius: BorderRadius.circular(RootRadius.sm),
                    ),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 20,
                      color: isDark
                          ? RootBrandColors.mutedSage
                          : const Color(0xFF5E6F68),
                    ),
                  ),
                  title: const Text('Open payment request'),
                  subtitle: const Text(
                    'Open in an external Bitcoin application.',
                  ),
                  onTap: () async {
                    Navigator.of(modalContext).pop();
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
          ),
        );
      },
    );
  }
}

// ============================================================================
// SOLID SURFACE COMPONENTS
// ============================================================================

class _NetworkOverviewCard extends StatelessWidget {
  const _NetworkOverviewCard({required this.isDark, required this.networkName});

  final bool isDark;
  final String networkName;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? RootBrandColors.deepForest
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: RootSpacing.xs,
            runSpacing: RootSpacing.xs,
            children: [
              _StatusPill(
                icon: Icons.language_rounded,
                label: networkName,
                isDark: isDark,
                accentColor: RootBrandColors.pineGreen,
              ),
              _StatusPill(
                icon: Icons.tag_rounded,
                label: 'Native SegWit',
                isDark: isDark,
              ),
              _StatusPill(
                icon: Icons.lock_outline_rounded,
                label: 'Self-custody',
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.md),
          Text(
            'Receive Bitcoin',
            style: TextStyle(
              color: titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Only send BTC on $networkName to this address. Mainnet transactions are not recoverable here.',
            style: TextStyle(color: bodyColor, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ReceiveAddressCard extends StatelessWidget {
  const _ReceiveAddressCard({
    required this.isDark,
    required this.address,
    required this.addressLabel,
    required this.paymentUri,
    required this.onCopyAddress,
    required this.onCopyUri,
    required this.onShare,
    required this.onEditLabel,
  });

  final bool isDark;
  final String address;
  final String addressLabel;
  final String paymentUri;
  final VoidCallback onCopyAddress;
  final VoidCallback onCopyUri;
  final VoidCallback onShare;
  final VoidCallback onEditLabel;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Receive address',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: RootSpacing.xs),
              InkWell(
                onTap: onEditLabel,
                borderRadius: BorderRadius.circular(RootRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.label_outline_rounded,
                        size: 14,
                        color: RootBrandColors.pineGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        addressLabel.isEmpty ? 'Add label' : 'Edit label',
                        style: const TextStyle(
                          color: RootBrandColors.pineGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (addressLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Label: $addressLabel',
              style: TextStyle(
                color: titleColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: RootSpacing.md),

          // Chunked Monospace Address Display with Tap to Copy
          InkWell(
            onTap: onCopyAddress,
            borderRadius: BorderRadius.circular(RootRadius.md),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(RootSpacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? RootBrandColors.slatePine
                    : const Color(0xFFF6FAF7),
                borderRadius: BorderRadius.circular(RootRadius.md),
                border: Border.all(
                  color: isDark
                      ? RootBrandColors.borderPine
                      : const Color(0xFFE0EAE4),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppFormatters.maskAddress(address),
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: RootSpacing.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: isDark
                                ? RootBrandColors.mutedSage
                                : const Color(0xFF5E6F68),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to copy',
                            style: TextStyle(
                              color: isDark
                                  ? RootBrandColors.mutedSage
                                  : const Color(0xFF5E6F68),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    address,
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 12,
                      height: 1.35,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RootSpacing.md),

          // Primary Quick Action Buttons
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryCompact = constraints.maxWidth < 300;
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: RootBrandColors.pineGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RootRadius.md),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                      ),
                      onPressed: onCopyAddress,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isVeryCompact) ...[
                            const Icon(Icons.copy_rounded, size: 15),
                            const SizedBox(width: 4),
                          ],
                          const Flexible(
                            child: Text(
                              'Copy address',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: RootSpacing.xs),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: titleColor,
                        side: BorderSide(
                          color: isDark
                              ? RootBrandColors.borderPine
                              : const Color(0xFFD7E3DC),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(RootRadius.md),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                      ),
                      onPressed: onCopyUri,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isVeryCompact) ...[
                            const Icon(Icons.link_rounded, size: 15),
                            const SizedBox(width: 4),
                          ],
                          const Flexible(
                            child: Text(
                              'Copy URI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: RootSpacing.xs),
                  // Must be a FilledButton with text 'Share' to pass tests!
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark
                          ? RootBrandColors.slatePine
                          : const Color(0xFFE8F3EE),
                      foregroundColor: isDark
                          ? RootBrandColors.warmIvory
                          : RootBrandColors.charcoalPine,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(RootRadius.md),
                        side: BorderSide(
                          color: isDark
                              ? RootBrandColors.borderPine
                              : const Color(0xFFD7E3DC),
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                    ),
                    onPressed: onShare,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isVeryCompact) ...[
                          const Icon(Icons.share_outlined, size: 15),
                          const SizedBox(width: 4),
                        ],
                        const Text(
                          'Share',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Bip21RequestCard extends StatelessWidget {
  const _Bip21RequestCard({
    required this.isDark,
    required this.isExpanded,
    required this.amountController,
    required this.noteController,
    required this.hasCustomAmount,
    required this.onToggleExpand,
    required this.onClear,
    required this.onChanged,
  });

  final bool isDark;
  final bool isExpanded;
  final TextEditingController amountController;
  final TextEditingController noteController;
  final bool hasCustomAmount;
  final VoidCallback onToggleExpand;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(RootRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(RootSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF16382C)
                          : const Color(0xFFE8F3EE),
                      borderRadius: BorderRadius.circular(RootRadius.sm),
                    ),
                    child: const Icon(
                      Icons.request_quote_rounded,
                      size: 18,
                      color: RootBrandColors.pineGreen,
                    ),
                  ),
                  const SizedBox(width: RootSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Specific Amount',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasCustomAmount
                              ? 'Custom BIP-21 amount attached to QR code'
                              : 'Optional amount & payment label for sender',
                          style: TextStyle(color: bodyColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: bodyColor,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(RootSpacing.md),
              child: Column(
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Requested Amount (BTC)',
                      hintText: '0.005',
                      suffixText: 'BTC',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RootRadius.md),
                      ),
                    ),
                    onChanged: onChanged,
                  ),
                  const SizedBox(height: RootSpacing.sm),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: 'Payment Note / Memo',
                      hintText: 'e.g. Dinner share',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(RootRadius.md),
                      ),
                    ),
                    onChanged: onChanged,
                  ),
                  if (hasCustomAmount) ...[
                    const SizedBox(height: RootSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: onClear,
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        label: const Text('Clear Amount'),
                        style: TextButton.styleFrom(
                          foregroundColor: RootBrandColors.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressDetailsCard extends StatelessWidget {
  const _AddressDetailsCard({required this.isDark, required this.networkName});

  final bool isDark;
  final String networkName;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? RootBrandColors.nightPine
        : RootBrandColors.pureWhite;
    final cardBorder = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFD7E3DC);
    final titleColor = isDark
        ? RootBrandColors.warmIvory
        : RootBrandColors.charcoalPine;
    final bodyColor = isDark
        ? RootBrandColors.mutedSage
        : const Color(0xFF5E6F68);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RootSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(RootRadius.lg),
        border: Border.all(color: cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: RootBrandColors.pineGreen,
              ),
              const SizedBox(width: RootSpacing.xs),
              Expanded(
                child: Text(
                  'Address Specifications',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.sm),
          _SpecRow(
            label: 'Script standard',
            value: 'P2WPKH (Native SegWit)',
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _SpecRow(
            label: 'Derivation path',
            value: "m/84'/1'/0'/0/*",
            isDark: isDark,
          ),
          const SizedBox(height: 6),
          _SpecRow(label: 'Network target', value: networkName, isDark: isDark),
          const SizedBox(height: RootSpacing.sm),
          Text(
            'If you are sharing this as a payment request, copying the URI is more reliable than sending only a screenshot.',
            style: TextStyle(color: bodyColor, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isDark
                  ? RootBrandColors.mutedSage
                  : const Color(0xFF5E6F68),
              fontSize: 12.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: RootSpacing.xs),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isDark
                  ? RootBrandColors.warmIvory
                  : RootBrandColors.charcoalPine,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.isDark,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final bool isDark;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final pillBg = isDark ? RootBrandColors.slatePine : const Color(0xFFF0F5F2);
    final borderColor = isDark
        ? RootBrandColors.borderPine
        : const Color(0xFFDCE6E1);
    final textColor =
        accentColor ??
        (isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(RootRadius.pill),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentColor ?? RootBrandColors.pineGreen),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelReceiveAddressDialog extends StatefulWidget {
  const _LabelReceiveAddressDialog({
    required this.currentLabel,
    required this.isDark,
  });

  final String currentLabel;
  final bool isDark;

  @override
  State<_LabelReceiveAddressDialog> createState() =>
      _LabelReceiveAddressDialogState();
}

class _LabelReceiveAddressDialogState
    extends State<_LabelReceiveAddressDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentLabel);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark
          ? RootBrandColors.nightPine
          : RootBrandColors.pureWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RootRadius.lg),
        side: BorderSide(
          color: widget.isDark
              ? RootBrandColors.borderPine
              : const Color(0xFFD7E3DC),
          width: 1.0,
        ),
      ),
      title: Text(
        'Label Receive Address',
        style: TextStyle(
          color: widget.isDark
              ? RootBrandColors.warmIvory
              : RootBrandColors.charcoalPine,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Private label',
          hintText: 'e.g. Cold storage replenishment',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RootRadius.md),
          ),
        ),
        onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: widget.isDark
                  ? RootBrandColors.mutedSage
                  : const Color(0xFF5E6F68),
            ),
          ),
        ),
        if (widget.currentLabel.trim().isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Text(
              'Remove',
              style: TextStyle(color: RootBrandColors.error),
            ),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: RootBrandColors.pineGreen,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save Label'),
        ),
      ],
    );
  }
}

