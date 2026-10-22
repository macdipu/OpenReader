import 'dart:io';

import 'package:flutter/material.dart';

import '../../../domain/models/document_category.dart';
import '../../../domain/models/document_model.dart';
import '../../../../services/utilities/pdf_thumbnail_service.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/file_size_formatter.dart';
import '../../utils/document_date_formatter.dart';

/// Shared file row used by All Files, Search, Recents, and Favorites
/// (BRD 9.4 - File Row Information / Overflow Actions).
///
/// Follows DESIGN_SPEC.md "File/Document list row": format badge, title,
/// metadata line, optional reading-progress sliver, trailing star+overflow.
class DocumentListTile extends StatelessWidget {
  final DocumentModel document;
  final bool isFavorite;
  final VoidCallback onTap;

  /// Secondary action on long-press - All Files' action sheet (UX-08).
  final VoidCallback? onLongPress;
  final ValueChanged<bool> onToggleFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onShowInfo;
  final VoidCallback? onOpenWith;
  final VoidCallback? onRemoveFromRecent;
  final VoidCallback? onDelete;
  final String? trailingLabel;

  /// Search text to mark in the title (case-insensitive), so a result shows
  /// why it matched (UX-25). Empty or null renders the plain title.
  final String? highlight;

  /// 0-1 reading progress. When set, a thin fill bar renders under the
  /// metadata line (Favorites & History / Home "Continue Reading" rows).
  final double? progress;

  /// Compact 56-64dp row (All Files / Recents) instead of the rich 72-80dp
  /// row (Home / Favorites / Search).
  final bool dense;

  const DocumentListTile({
    super.key,
    required this.document,
    required this.isFavorite,
    required this.onTap,
    this.onLongPress,
    required this.onToggleFavorite,
    this.onShare,
    this.onShowInfo,
    this.onOpenWith,
    this.onRemoveFromRecent,
    this.onDelete,
    this.trailingLabel,
    this.highlight,
    this.progress,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = document.category.accentColor(context);
    final tint = document.category.tintColor(context);
    final badgeSize = dense ? 40.0 : 44.0;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTapDown: (details) => _showContextMenu(context, details.globalPosition),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 10 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _DocumentThumbnail(document: document, size: badgeSize, accent: accent, tint: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    highlightMatches(
                      document.displayName,
                      highlight ?? '',
                      context.titleMedium,
                      TextStyle(backgroundColor: context.secondaryContainer, color: context.onSecondaryContainer),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trailingLabel ??
                        '${formatFileSize(document.sizeBytes)} • ${formatDocumentDate(document.modifiedAt)} • ${document.category.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress!.clamp(0, 1),
                        minHeight: 3,
                        backgroundColor: context.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation(context.secondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFavorite ? context.secondary : context.onSurfaceVariant,
              ),
              onPressed: () => onToggleFavorite(!isFavorite),
            ),
            PopupMenuButton<_DocumentAction>(
              tooltip: 'More actions',
              icon: Icon(Icons.more_vert, color: context.onSurfaceVariant),
              onSelected: (action) => _handle(action),
              itemBuilder: _menuItems,
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<_DocumentAction>> _menuItems(BuildContext context) => [
        if (onShare != null) const PopupMenuItem(value: _DocumentAction.share, child: Text('Share')),
        if (onShowInfo != null) const PopupMenuItem(value: _DocumentAction.info, child: Text('File Information')),
        if (onOpenWith != null) const PopupMenuItem(value: _DocumentAction.openWith, child: Text('Open With')),
        if (onRemoveFromRecent != null)
          const PopupMenuItem(value: _DocumentAction.removeFromRecent, child: Text('Remove from Recent')),
        // Permanent file deletion, so styled as destructive (UX-15).
        if (onDelete != null)
          PopupMenuItem(
            value: _DocumentAction.delete,
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
      ];

  /// Right-click (desktop) shows the ⋮ menu's actions at the pointer (UX-34).
  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<_DocumentAction>(
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
      items: _menuItems(context),
    );
    if (action != null) _handle(action);
  }

  void _handle(_DocumentAction action) {
    switch (action) {
      case _DocumentAction.share:
        onShare?.call();
        break;
      case _DocumentAction.info:
        onShowInfo?.call();
        break;
      case _DocumentAction.openWith:
        onOpenWith?.call();
        break;
      case _DocumentAction.removeFromRecent:
        onRemoveFromRecent?.call();
        break;
      case _DocumentAction.delete:
        onDelete?.call();
        break;
    }
  }
}

enum _DocumentAction { share, info, openWith, removeFromRecent, delete }

/// PDF first-page preview with the format icon stacked on its corner, per
/// PdfThumbnailService; every other format (no renderer available - see
/// that service's doc comment) falls back to the plain code badge.
class _DocumentThumbnail extends StatelessWidget {
  final DocumentModel document;
  final double size;
  final Color accent;
  final Color tint;

  const _DocumentThumbnail({required this.document, required this.size, required this.accent, required this.tint});

  @override
  Widget build(BuildContext context) {
    if (document.category != DocumentCategory.pdf) return _badge(context);

    return FutureBuilder<File?>(
      future: PdfThumbnailService.instance.getThumbnail(document),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return _badge(context);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  file,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _badge(context),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: size * 0.42,
                  height: size * 0.42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.surfaceContainerLowest, width: 1.5),
                  ),
                  child: Icon(document.category.icon, size: size * 0.24, color: accent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _badge(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        document.category.shortCode,
        style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// [text] as spans with each case-insensitive occurrence of [query] styled
/// with [matchStyle] over [style]. A blank query yields one plain span.
TextSpan highlightMatches(String text, String query, TextStyle? style, TextStyle matchStyle) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return TextSpan(text: text, style: style);
  final haystack = text.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final index = haystack.indexOf(needle, start);
    if (index < 0) {
      if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
      break;
    }
    if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
    spans.add(TextSpan(text: text.substring(index, index + needle.length), style: matchStyle));
    start = index + needle.length;
  }
  return TextSpan(style: style, children: spans);
}
