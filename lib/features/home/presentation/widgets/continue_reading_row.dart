import 'package:flutter/material.dart';

import '../../../../core/domain/models/recent_document_model.dart';
import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/widgets/document/document_list_tile.dart';
import '../home_formatters.dart';
import 'hover_surface.dart';

/// Desktop Home's "Continue reading": one row of up to four equal cards that always fits the
/// pane - as many columns (1-4) as leave each card at least [minCardWidth].
class ContinueReadingRow extends StatelessWidget {
  final List<RecentDocumentModel> recents;
  final ValueChanged<RecentDocumentModel> onOpen;
  final void Function(RecentDocumentModel recent, Offset position) onContextMenu;

  const ContinueReadingRow({super.key, required this.recents, required this.onOpen, required this.onContextMenu});

  static const minCardWidth = 200.0;
  static const gap = 16.0;
  static const maxColumns = 4;

  /// Cards stop growing here; with few cards the row leaves the rest of the width empty.
  static const maxCardWidth = 360.0;

  /// Columns that fit [width].
  static int columnsFor(double width) => ((width + gap) / (minCardWidth + gap)).floor().clamp(1, maxColumns);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // As many columns as there are cards (up to what fits), each at most [maxCardWidth], so one
      // or two cards are not squeezed into a quarter of the pane.
      final columns = columnsFor(constraints.maxWidth).clamp(1, recents.isEmpty ? 1 : recents.length);
      final cardWidth =
          ((constraints.maxWidth - gap * (columns - 1)) / columns).clamp(0.0, maxCardWidth).toDouble();
      final shown = recents.take(columns).toList();
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, recent) in shown.indexed) ...[
              if (index > 0) const SizedBox(width: gap),
              SizedBox(
                width: cardWidth,
                child: ContinueReadingCard(
                  key: ValueKey('continue-card-${recent.document.id}'),
                  recent: recent,
                  onTap: () => onOpen(recent),
                  onSecondaryTap: (position) => onContextMenu(recent, position),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// A recent document with a saved position: thumbnail, name, format and size, and where and
/// when reading stopped. The whole card opens it.
class ContinueReadingCard extends StatelessWidget {
  final RecentDocumentModel recent;
  final VoidCallback onTap;
  final ValueChanged<Offset> onSecondaryTap;

  const ContinueReadingCard({super.key, required this.recent, required this.onTap, required this.onSecondaryTap});

  @override
  Widget build(BuildContext context) {
    final document = recent.document;
    final position = readingPositionLabel(recent);
    final when = formatRelativeTimeLong(recent.lastOpenedAt);
    final secondary = context.bodySmall?.copyWith(color: context.onSurfaceVariant);
    return HoverSurface(
      onTap: onTap,
      onSecondaryTap: onSecondaryTap,
      semanticLabel: 'Continue reading ${document.displayName}',
      builder: (context, states) => AnimatedContainer(
        duration: homeMotion,
        curve: homeCurve,
        // Hover lifts the card a little.
        transform: Matrix4.translationValues(0, states.hovered && !states.pressed ? -2 : 0, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: focusRing(context, states, idle: states.hovered ? context.outline : context.outlineVariant),
          boxShadow: [
            if (states.hovered)
              BoxShadow(color: context.shadow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DocumentThumbnail(document: document, size: 44, readingPosition: recent.readingPosition),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.titleSmall),
                      const SizedBox(height: 2),
                      Text(formatAndSize(recent), maxLines: 1, overflow: TextOverflow.ellipsis, style: secondary),
                      const SizedBox(height: 2),
                      Text(
                        position == null ? when : '$position · $when',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (recent.progress case final progress?) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: context.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(context.secondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
