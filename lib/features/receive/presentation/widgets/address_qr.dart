import 'package:flutter/material.dart';
import 'package:root_wallet/core/utils/formatters.dart';

class AddressQr extends StatelessWidget {
  const AddressQr({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_2, size: 128),
            const SizedBox(height: 12),
            Text(
              AppFormatters.maskAddress(address),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
