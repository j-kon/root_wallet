import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:root_wallet/app/theme/layout.dart';
import 'package:root_wallet/core/widgets/glass_surface.dart';

Future<String?> showPinEntryDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String confirmLabel = 'Continue',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) {
      return _PinEntryDialog(
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
      );
    },
  );
}

class _PinEntryDialog extends StatefulWidget {
  const _PinEntryDialog({
    required this.title,
    this.subtitle,
    required this.confirmLabel,
  });

  final String title;
  final String? subtitle;
  final String confirmLabel;

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isReady = _controller.text.trim().length == 6;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: GlassSurface(
          borderRadius: BorderRadius.circular(AppRadius.lg + 6),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'PIN'),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (!isReady) {
                    return;
                  }
                  Navigator.of(context).pop(_controller.text.trim());
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: !isReady
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pop(_controller.text.trim()),
                      child: Text(widget.confirmLabel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
