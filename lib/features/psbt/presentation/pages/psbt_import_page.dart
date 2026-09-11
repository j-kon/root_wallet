import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:root_wallet/app/routing/routes.dart';
import 'package:root_wallet/app/theme/brand/root_brand_colors.dart';
import 'package:root_wallet/app/theme/brand/root_brand_radius.dart';
import 'package:root_wallet/app/theme/brand/root_brand_spacing.dart';
import 'package:root_wallet/app/theme/colors.dart';
import 'package:root_wallet/core/widgets/app_scaffold.dart';
import 'package:root_wallet/core/widgets/magnetic_pressable.dart';
import 'package:root_wallet/features/psbt/presentation/providers/psbt_providers.dart';

class PsbtImportPage extends ConsumerStatefulWidget {
  const PsbtImportPage({super.key});

  @override
  ConsumerState<PsbtImportPage> createState() => _PsbtImportPageState();
}

class _PsbtImportPageState extends ConsumerState<PsbtImportPage> {
  final _controller = TextEditingController();
  String? _error;
  bool _isValidating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _controller.text = text;
        _error = null;
      });
    }
  }

  Future<void> _inspectPsbt() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Please enter or paste a PSBT Base64 string.');
      return;
    }

    setState(() {
      _isValidating = true;
      _error = null;
    });

    try {
      final psbtService = ref.read(psbtServiceProvider);
      // Validate by attempting inspection
      await psbtService.inspectPsbt(raw);

      if (mounted) {
        Navigator.of(context).pushNamed(
          AppRoutes.psbtInspect,
          arguments: raw,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isValidating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return AppScaffold(
      title: 'Import PSBT',
      body: ListView(
        padding: const EdgeInsets.all(RootSpacing.lg),
        children: [
          Text(
            'Partially Signed Bitcoin Transaction',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
            ),
          ),
          const SizedBox(height: RootSpacing.xs),
          Text(
            'Import an unsigned or partially signed transaction to inspect recipient outputs, fee, change address, and sign securely.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
              height: 1.4,
            ),
          ),
          const SizedBox(height: RootSpacing.lg),
          Container(
            decoration: BoxDecoration(
              color: isDark ? RootBrandColors.nightPine : RootBrandColors.pureWhite,
              borderRadius: BorderRadius.circular(RootRadius.md),
              border: Border.all(
                color: _error != null
                    ? RootBrandColors.error
                    : (isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC)),
              ),
            ),
            padding: const EdgeInsets.all(RootSpacing.sm),
            child: TextField(
              controller: _controller,
              maxLines: 8,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
              ),
              decoration: InputDecoration(
                hintText: 'Paste Base64 PSBT (e.g. cHNidP8BAFICAAAA...)',
                hintStyle: TextStyle(
                  color: isDark ? RootBrandColors.borderPine : RootBrandColors.mutedSage,
                ),
                border: InputBorder.none,
              ),
              onChanged: (_) {
                if (_error != null) {
                  setState(() => _error = null);
                }
              },
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: RootSpacing.xs),
            Text(
              _error!,
              style: const TextStyle(
                color: RootBrandColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: RootSpacing.md),
          Row(
            children: [
              Expanded(
                child: MagneticPressable(
                  onTap: _pasteFromClipboard,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: RootSpacing.sm,
                      horizontal: RootSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? RootBrandColors.slatePine : const Color(0xFFE8EFEA),
                      borderRadius: BorderRadius.circular(RootRadius.md),
                      border: Border.all(
                        color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.paste_rounded,
                          size: 18,
                          color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                        ),
                        const SizedBox(width: RootSpacing.xs),
                        Text(
                          'Paste',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? RootBrandColors.warmIvory : RootBrandColors.charcoalPine,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RootSpacing.md),
              Expanded(
                child: MagneticPressable(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _controller.clear();
                      _error = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: RootSpacing.sm,
                      horizontal: RootSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(RootRadius.md),
                      border: Border.all(
                        color: isDark ? RootBrandColors.borderPine : const Color(0xFFD7E3DC),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? RootBrandColors.mutedSage : const Color(0xFF5E6F68),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RootSpacing.xl),
          MagneticPressable(
            onTap: _isValidating ? null : _inspectPsbt,
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
                child: _isValidating
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
                        'Inspect Transaction',
                        style: TextStyle(
                          color: RootBrandColors.warmIvory,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: RootSpacing.xl),
          Container(
            padding: const EdgeInsets.all(RootSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? RootBrandColors.slatePine : const Color(0xFFE8EFEA),
              borderRadius: BorderRadius.circular(RootRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: RootBrandColors.pineGreen,
                  size: 20,
                ),
                const SizedBox(width: RootSpacing.sm),
                Expanded(
                  child: Text(
                    'Signing a PSBT requires PIN authentication and verifies that the inputs belong to this wallet before executing signatures.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? RootBrandColors.mutedSage : RootBrandColors.charcoalPine,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
