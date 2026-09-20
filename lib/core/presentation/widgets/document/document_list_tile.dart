import 'package:flutter/material.dart';

import '../../../domain/extensions/extension_export.dart';
import '../../../domain/models/document_model.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/file_size_formatter.dart';

/// Shared file row used by All Files, Search, Recents, and Favorites
/// (BRD 9.4 - File Row Information / Overflow Actions).
///
/// Follows DESIGN_SPEC.md "File/Document list row": format badge, title,
/// metadata line, optional reading-progress sliver, trailing star+overflow.
class DocumentListTile extends StatelessWidget {
  final DocumentModel document;
  final bool isFavorite;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onShowInfo;
  final VoidCallback? onOpenWith;
  final VoidCallback? onRemoveFromRecent;
  final String? trailingLabel;

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
    required this.onToggleFavorite,
    this.onShare,
    this.onShowInfo,
    this.onOpenWith,
    this.onRemoveFromRecent,
    this.trailingLabel,
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 10 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: badgeSize,
              height: badgeSize,
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    document.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trailingLabel ??
                        '${formatFileSize(document.sizeBytes)} • ${document.modifiedAt.toDMYString()} • ${document.category.label}',
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
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFavorite ? context.secondary : context.onSurfaceVariant,
              ),
              onPressed: () => onToggleFavorite(!isFavorite),
            ),
            PopupMenuButton<_DocumentAction>(
              icon: Icon(Icons.more_vert, color: context.onSurfaceVariant),
              onSelected: (action) => _handle(action),
              itemBuilder: (context) => [
                if (onShare != null) const PopupMenuItem(value: _DocumentAction.share, child: Text('Share')),
                if (onShowInfo != null)
                  const PopupMenuItem(value: _DocumentAction.info, child: Text('File Information')),
                if (onOpenWith != null)
                  const PopupMenuItem(value: _DocumentAction.openWith, child: Text('Open With')),
                if (onRemoveFromRecent != null)
                  const PopupMenuItem(value: _DocumentAction.removeFromRecent, child: Text('Remove from Recent')),
              ],
            ),
          ],
        ),
      ),
    );
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
    }
  }
}

enum _DocumentAction { share, info, openWith, removeFromRecent }
