import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/domain/models/document_model.dart';
import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/file_size_formatter.dart';
import 'package:universal_document_viewer/plain_text.dart';

/// Shows the file's metadata and the figures [MarkdownStats] measured.
/// Everything listed is read from the file or counted from its text.
Future<void> showMarkdownDetails(BuildContext context, {required DocumentModel document, required MarkdownStats stats}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _MarkdownDetailsDialog(document: document, stats: stats),
  );
}

class _MarkdownDetailsDialog extends StatelessWidget {
  final DocumentModel document;
  final MarkdownStats stats;

  const _MarkdownDetailsDialog({required this.document, required this.stats});

  @override
  Widget build(BuildContext context) {
    final number = NumberFormat.decimalPattern();
    final reading = stats.readingMinutes == 0
        ? '—'
        : (stats.readingMinutes < 2 ? '1 min' : '${stats.readingMinutes} min');
    final rows = <(String, String)>[
      ('Name', document.displayName),
      ('Path', document.path),
      ('Size', formatFileSize(document.sizeBytes)),
      ('Modified', DateFormat.yMMMd().add_jm().format(document.modifiedAt)),
      ('Words', number.format(stats.words)),
      ('Characters', number.format(stats.characters)),
      ('Lines', number.format(stats.lines)),
      ('Headings', number.format(stats.headings)),
      ('Links', number.format(stats.links)),
      ('Images', number.format(stats.images)),
      ('Reading time', reading),
    ];
    return AlertDialog(
      title: const Text('Details'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: SelectionArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 108, child: Text(label, style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant))),
                        Expanded(child: Text(value, style: context.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
    );
  }
}
