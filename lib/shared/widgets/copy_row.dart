import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyRow extends StatelessWidget {
  const CopyRow({super.key, required this.value, this.label});

  final String value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null)
                Text(label!, style: Theme.of(context).textTheme.bodySmall),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        IconButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Copied')));
            }
          },
          icon: const Icon(Icons.copy),
        ),
      ],
    );
  }
}
