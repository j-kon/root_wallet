import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/utils/formatters.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/loading.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/features/psbt/domain/entities/psbt_details.dart';
import 'package:root_wallet/features/psbt/presentation/pages/psbt_export_page.dart';
import 'package:root_wallet/features/psbt/presentation/providers/psbt_providers.dart';
import 'package:root_wallet/features/send/presentation/pages/send_success_page.dart';
import 'package:root_wallet/features/settings/presentation/providers/security_providers.dart';

class PsbtInspectionPage extends ConsumerStatefulWidget {
  const PsbtInspectionPage({
    super.key,
    required this.psbtBase64,
  });

  final String psbtBase64;

  @override
  ConsumerState<PsbtInspectionPage> createState() => _PsbtInspectionPageState();
}

class _PsbtInspectionPageState extends ConsumerState<PsbtInspectionPage> {
  late String _currentPsbtBase64;

  @override
  void initState() {
    super.initState();
    _currentPsbtBase64 = widget.psbtBase64;
  }

  Future<void> _signPsbt(BuildContext context, PsbtDetails details) async {
    HapticFeedback.lightImpact();

    // Security Gate / Re-auth check
    try {
      final lockController = ref.read(lockControllerProvider.notifier);
      final reauthOk = await lockController.requireReauth();
      // If biometrics/PIN enabled but reauth failed, cancel
      final lockState = ref.read(lockControllerProvider).valueOrNull;
      if (lockState != null &&
          lockState.isBiometricsEnabled &&
          lockState.isBiometricAvailable &&
          !reauthOk) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required to sign PSBT.'),
            ),
          );
        }
        return;
      }
    } catch (_) {}

    final result = await ref
        .read(psbtActionControllerProvider.notifier)
        .sign(_currentPsbtBase64);

    if (result != null && mounted) {
      setState(() {
        _currentPsbtBase64 = result.signedPsbtBase64;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isFinalized
                  ? 'Transaction successfully signed and finalized!'
                  : 'Signed your inputs. PSBT is partially signed.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _broadcastPsbt(BuildContext context, PsbtDetails details) async {
    HapticFeedback.heavyImpact();
    final txid = await ref
        .read(psbtActionControllerProvider.notifier)
        .broadcast(_currentPsbtBase64);

    if (txid != null && mounted) {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.sendSuccess,
        arguments: SendSuccessPageArgs(
          txId: txid,
          amountSats: details.totalOutputSats,
          feeSats: details.feeSats ?? 0,
          sentAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final detailsAsync = ref.watch(psbtInspectionProvider(_currentPsbtBase64));
    final actionState = ref.watch(psbtActionControllerProvider);

    return AppScaffold(
      title: 'Inspect PSBT',
      body: detailsAsync.when(
        loading: () => const Loading(label: 'Inspecting transaction...'),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(RootSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: RootBrandColors.error, size: 48),
                const SizedBox(height: RootSpacing.md),
                Text(
                  'Failed to inspect PSBT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                  ),
                ),
                const SizedBox(height: RootSpacing.xs),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: RootBrandColors.error, fontSize: 13),
                ),
                const SizedBox(height: RootSpacing.lg),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
        data: (details) {
          final isFinalized = details.isFinalized;
          final canSign = details.canSign;

          return ListView(
            padding: const EdgeInsets.all(RootSpacing.lg),
            children: [
              // 1. Status & Network Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFinalized
                          ? RootBrandColors.pineGreen.withValues(alpha: 0.15)
                          : RootBrandColors.amberAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(RootRadius.sm),
                      border: Border.all(
                        color: isFinalized
                            ? RootBrandColors.pineGreen
                            : RootBrandColors.amberAccent,
                      ),
                    ),
                    child: Text(
                      isFinalized ? 'FINALIZED' : (canSign ? 'READY TO SIGN' : 'UNSIGNED'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isFinalized
                            ? RootBrandColors.pineGreen
                            : RootBrandColors.amberAccent,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
                      borderRadius: BorderRadius.circular(RootRadius.sm),
                      border: Border.all(
                        color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                      ),
                    ),
                    child: Text(
                      'TESTNET',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RootSpacing.md),

              // 2. Warning Banners
              if (details.hasUnownedInputs) ...[
                Container(
                  padding: const EdgeInsets.all(RootSpacing.md),
                  decoration: BoxDecoration(
                    color: RootBrandColors.amberAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(RootRadius.md),
                    border: Border.all(color: RootBrandColors.amberAccent),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: RootBrandColors.amberAccent, size: 22),
                      SizedBox(width: RootSpacing.sm),
                      Expanded(
                        child: Text(
                          'Notice: One or more inputs do not belong to your active wallet.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: RootBrandColors.amberAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RootSpacing.md),
              ],
              if (!canSign) ...[
                Container(
                  padding: const EdgeInsets.all(RootSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? RootBrandColors.slatePine : const Color(0xFFE8EFEA),
                    borderRadius: BorderRadius.circular(RootRadius.md),
                    border: Border.all(
                      color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined, color: RootBrandColors.pineGreen, size: 22),
                      const SizedBox(width: RootSpacing.sm),
                      Expanded(
                        child: Text(
                          'Watch-Only Mode: This wallet cannot sign transactions. Export the PSBT to a signing device.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RootSpacing.md),
              ],

              // 3. Overview Card
              Container(
                padding: const EdgeInsets.all(RootSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
                  borderRadius: BorderRadius.circular(RootRadius.lg),
                  border: Border.all(
                    color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                  ),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Total Output',
                      '${AppFormatters.sats(details.totalOutputSats)} (${AppFormatters.btcFromSats(details.totalOutputSats)})',
                      isDark: isDark,
                      bold: true,
                    ),
                    const Divider(),
                    if (details.totalInputSats != null) ...[
                      _buildSummaryRow(
                        'Total Input',
                        '${AppFormatters.sats(details.totalInputSats!)} (${AppFormatters.btcFromSats(details.totalInputSats!)})',
                        isDark: isDark,
                      ),
                      const Divider(),
                    ],
                    _buildSummaryRow(
                      'Network Fee',
                      details.feeSats != null
                          ? '${AppFormatters.sats(details.feeSats!)} (${AppFormatters.btcFromSats(details.feeSats!)})'
                          : 'Unknown',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RootSpacing.lg),

              // 4. Outputs List
              Text(
                'Outputs (${details.outputs.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                ),
              ),
              const SizedBox(height: RootSpacing.sm),
              ...details.outputs.map(
                (out) => Container(
                  margin: const EdgeInsets.only(bottom: RootSpacing.sm),
                  padding: const EdgeInsets.all(RootSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
                    borderRadius: BorderRadius.circular(RootRadius.md),
                    border: Border.all(
                      color: out.isChange
                          ? RootBrandColors.pineGreen.withValues(alpha: 0.5)
                          : (isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC)),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppFormatters.sats(out.amountSats),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                            ),
                          ),
                          if (out.isChange)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: RootBrandColors.pineGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(RootRadius.xs),
                              ),
                              child: const Text(
                                'CHANGE (MINE)',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: RootBrandColors.pineGreen,
                                ),
                              ),
                            )
                          else if (out.isMine)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: RootBrandColors.pineGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(RootRadius.xs),
                              ),
                              child: const Text(
                                'MINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: RootBrandColors.pineGreen,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? RootBrandColors.slatePine : const Color(0xFFE8EFEA),
                                borderRadius: BorderRadius.circular(RootRadius.xs),
                              ),
                              child: Text(
                                'RECIPIENT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        out.address != null
                            ? out.address!
                            : AppFormatters.maskAddress(out.scriptPubkeyHex),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RootSpacing.md),

              // 5. Inputs List
              Text(
                'Inputs (${details.inputs.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                ),
              ),
              const SizedBox(height: RootSpacing.sm),
              ...details.inputs.map(
                (inp) => Container(
                  margin: const EdgeInsets.only(bottom: RootSpacing.sm),
                  padding: const EdgeInsets.all(RootSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
                    borderRadius: BorderRadius.circular(RootRadius.md),
                    border: Border.all(
                      color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppFormatters.maskAddress(inp.outpoint),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                              ),
                            ),
                            if (inp.amountSats != null)
                              Text(
                                AppFormatters.sats(inp.amountSats!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: inp.isMine
                              ? RootBrandColors.pineGreen.withValues(alpha: 0.15)
                              : RootBrandColors.amberAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(RootRadius.xs),
                        ),
                        child: Text(
                          inp.isMine ? 'OWNED' : 'EXTERNAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: inp.isMine
                                ? RootBrandColors.pineGreen
                                : RootBrandColors.amberAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: RootSpacing.xl),

              // Action error display
              if (actionState.errorMessage != null) ...[
                Text(
                  actionState.errorMessage!,
                  style: const TextStyle(color: RootBrandColors.error, fontSize: 13),
                ),
                const SizedBox(height: RootSpacing.md),
              ],

              // 6. Primary Action Buttons
              if (canSign && !isFinalized) ...[
                MagneticPressable(
                  onTap: actionState.isLoading ? null : () => _signPsbt(context, details),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: RootSpacing.md,
                      horizontal: RootSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: RootBrandColors.pineGreen,
                      borderRadius: BorderRadius.circular(RootRadius.md),
                    ),
                    child: Center(
                      child: actionState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  RootBrandColors.warmIvory,
                                ),
                              ),
                            )
                          : const Text(
                              'Sign PSBT',
                              style: TextStyle(
                                color: RootBrandColors.warmIvory,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: RootSpacing.md),
              ],

              if (isFinalized) ...[
                MagneticPressable(
                  onTap: actionState.isLoading ? null : () => _broadcastPsbt(context, details),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: RootSpacing.md,
                      horizontal: RootSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: RootBrandColors.pineGreen,
                      borderRadius: BorderRadius.circular(RootRadius.md),
                    ),
                    child: Center(
                      child: actionState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  RootBrandColors.warmIvory,
                                ),
                              ),
                            )
                          : const Text(
                              'Broadcast Transaction',
                              style: TextStyle(
                                color: RootBrandColors.warmIvory,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: RootSpacing.md),
              ],

              // Export Button
              MagneticPressable(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.psbtExport,
                    arguments: PsbtExportArgs(
                      psbtBase64: _currentPsbtBase64,
                      isSigned: isFinalized,
                      txid: details.txid,
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: RootSpacing.md,
                    horizontal: RootSpacing.lg,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
                    borderRadius: BorderRadius.circular(RootRadius.md),
                    border: Border.all(
                      color: RootBrandColors.pineGreen,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isFinalized ? 'Export Signed PSBT' : 'Export Unsigned PSBT',
                      style: const TextStyle(
                        color: RootBrandColors.pineGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: RootSpacing.xl),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    required bool isDark,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
          ),
        ),
      ],
    );
  }
}
