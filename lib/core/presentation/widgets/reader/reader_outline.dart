import 'package:flutter/material.dart';
import 'package:universal_document_viewer/universal_document_viewer.dart';

import '../../theme/theme_extensions.dart';
import 'reader_toolbar.dart';

/// The "Contents" tool: the document's table of contents (a PDF's bookmarks, a Word document's
/// headings, a deck's slide titles, a Markdown file's headings) in a sheet; choosing an entry goes there.
class ReaderOutlineButton extends StatelessWidget {
  const ReaderOutlineButton({super.key, required this.load, required this.onSelected});

  /// The entries, from the document's controller. Read when the sheet opens.
  final Future<List<OutlineEntry>> Function() load;

  /// Called with the entry the reader chose, after the sheet has closed.
  final void Function(OutlineEntry entry) onSelected;

  @override
  Widget build(BuildContext context) => ReaderToolbarButton(
        icon: Icons.toc_rounded,
        tooltip: 'Contents',
        onPressed: () async {
          final entry = await showReaderOutline(context, load: load);
          if (entry != null) onSelected(entry);
        },
      );
}

/// Shows the outline sheet; the chosen entry, or null when it was dismissed.
Future<OutlineEntry?> showReaderOutline(
  BuildContext context, {
  required Future<List<OutlineEntry>> Function() load,
}) {
  return showModalBottomSheet<OutlineEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) => _OutlineSheet(load: load),
  );
}

class _OutlineSheet extends StatelessWidget {
  const _OutlineSheet({required this.load});

  final Future<List<OutlineEntry>> Function() load;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: FutureBuilder<List<OutlineEntry>>(
        future: load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
          }
          final entries = snapshot.data ?? const <OutlineEntry>[];
          if (entries.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Text(
                'This document has no contents list.',
                textAlign: TextAlign.center,
                style: context.bodyMedium,
              ),
            );
          }
          return ListView.builder(
            shrinkWrap: true,
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final entry = entries[i];
              final title = entry.title.trim().isEmpty ? 'Untitled' : entry.title.trim();
              return ListTile(
                dense: true,
                contentPadding: EdgeInsetsDirectional.only(start: 16.0 + entry.level * 16.0, end: 16),
                title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                // A heading that only groups others leads nowhere.
                enabled: entry.target != null,
                onTap: entry.target == null ? null : () => Navigator.of(context).pop(entry),
              );
            },
          );
        },
      ),
    );
  }
}
