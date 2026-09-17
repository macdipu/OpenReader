import 'package:flutter/material.dart';

import '../../../domain/extensions/extension_export.dart';
import '../../../domain/models/document_model.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/file_size_formatter.dart';

/// Shared file row used by All Files, Search, Recents, and Favorites
/// (BRD 9.4 - File Row Information / Overflow Actions).
class DocumentListTile extends StatelessWidget {
  final DocumentModel document;
  final bool isFavorite;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleFavorite;
  final VoidCallback? onShare;
  final VoidCallback? onShowInfo;
  final VoidCallback? onRemoveFromRecent;
  final String? trailingLabel;

  const DocumentListTile({
    super.key,
    required this.document,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    this.onShare,
    this.onShowInfo,
    this.onRemoveFromRecent,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(document.category.icon, color: context.primary, size: 32),
      title: Text(
        document.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.titleSmall,
      ),
      subtitle: Text(
        trailingLabel ??
            '${document.category.label} • ${formatFileSize(document.sizeBytes)} • '
                '${document.modifiedAt.toDMYString()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
      ),
      trailing: PopupMenuButton<_DocumentAction>(
        icon: Icon(Icons.more_vert, color: context.onSurfaceVariant),
        onSelected: (action) => _handle(action),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _DocumentAction.favorite,
            child: Text(isFavorite ? 'Remove Favorite' : 'Add Favorite'),
          ),
          if (onShare != null) const PopupMenuItem(value: _DocumentAction.share, child: Text('Share')),
          if (onShowInfo != null)
            const PopupMenuItem(value: _DocumentAction.info, child: Text('File Information')),
          if (onRemoveFromRecent != null)
            const PopupMenuItem(value: _DocumentAction.removeFromRecent, child: Text('Remove from Recent')),
        ],
      ),
    );
  }

  void _handle(_DocumentAction action) {
    switch (action) {
      case _DocumentAction.favorite:
        onToggleFavorite(!isFavorite);
        break;
      case _DocumentAction.share:
        onShare?.call();
        break;
      case _DocumentAction.info:
        onShowInfo?.call();
        break;
      case _DocumentAction.removeFromRecent:
        onRemoveFromRecent?.call();
        break;
    }
  }
}

enum _DocumentAction { favorite, share, info, removeFromRecent }
