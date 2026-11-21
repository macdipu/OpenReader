import 'package:flutter/material.dart';

import '../theme/theme_extensions.dart';
import '../utils/storage_access_help.dart';

/// The numbered steps for giving file access (numbered circles: this is a real sequence), then, when
/// the brand has one, a small "Or find it yourself" label with the manual path on one line.
class StorageAccessSteps extends StatelessWidget {
  final StorageAccessHelp help;
  const StorageAccessSteps({super.key, required this.help});

  @override
  Widget build(BuildContext context) {
    final body = context.bodyMedium?.copyWith(color: context.onSurface);
    final bold = body?.copyWith(fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < help.steps.length; i++)
          Padding(
            padding:
                EdgeInsets.only(bottom: i == help.steps.length - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: context.primaryContainer, shape: BoxShape.circle),
                  child: Text('${i + 1}',
                      style: context.labelMedium?.copyWith(
                          color: context.onPrimaryContainer,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text.rich(
                      TextSpan(
                        style: body,
                        children: [
                          for (final span in help.steps[i])
                            TextSpan(
                                text: span.text,
                                style: span.bold ? bold : null),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (help.manualPath != null) ...[
          const SizedBox(height: 16),
          Text(StorageAccessHelp.manualLabel,
              style: context.labelMedium?.copyWith(
                  color: context.onSurfaceVariant,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(help.manualPath!,
              style:
                  context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
        ],
      ],
    );
  }
}
