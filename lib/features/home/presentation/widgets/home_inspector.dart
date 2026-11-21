import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../../core/domain/models/document_category.dart';
import '../../../../core/domain/models/recent_document_model.dart';
import '../../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../../core/presentation/controllers/thumbnail_preferences.dart';
import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/file_size_formatter.dart';
import '../../../../core/presentation/widgets/document/document_list_tile.dart';
import '../../../../services/utilities/document_thumbnail_service.dart';
import '../home_controller.dart';
import '../home_formatters.dart';
import 'home_document_actions.dart';
import 'hover_surface.dart';
import 'middle_ellipsis_text.dart';

/// Desktop Home's right-hand pane: the selected document's preview, Open (the screen's one
/// primary action) and Open beside, its labeled actions and its details. With nothing
/// selected it says how to fill it.
class HomeInspector extends StatelessWidget {
  final HomeController controller;
  final DocumentInteractionController interactions;

  /// Shown as an overlay drawer: it gets a close button.
  final VoidCallback? onClose;

  const HomeInspector({super.key, required this.controller, required this.interactions, this.onClose});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('home-inspector'),
      color: context.surfaceContainerLowest,
      child: Obx(() {
        final recent = controller.selectedRecent;
        final close = onClose == null
            ? null
            : Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close details',
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              );
        if (recent == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (close != null) Padding(padding: const EdgeInsets.fromLTRB(16, 8, 8, 0), child: close),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 28, color: context.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text(
                          'Select a file to see its details',
                          textAlign: TextAlign.center,
                          style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        return _InspectorDetails(
          key: ValueKey('inspector-${recent.document.id}'),
          recent: recent,
          controller: controller,
          interactions: interactions,
          close: close,
        );
      }),
    );
  }
}

class _InspectorDetails extends StatelessWidget {
  final RecentDocumentModel recent;
  final HomeController controller;
  final DocumentInteractionController interactions;
  final Widget? close;

  const _InspectorDetails({
    super.key,
    required this.recent,
    required this.controller,
    required this.interactions,
    required this.close,
  });

  @override
  Widget build(BuildContext context) {
    final document = recent.document;
    final folder = p.dirname(document.path);
    final dateFormat = DateFormat.yMMMd().add_jm();
    final position = readingPositionLabel(recent);
    final secondary = context.bodySmall?.copyWith(color: context.onSurfaceVariant);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (close != null) close!,
          Center(child: _InspectorPreview(recent: recent)),
          const SizedBox(height: 16),
          Text(
            document.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: context.onSurface),
          ),
          const SizedBox(height: 4),
          Text(formatAndSize(recent), style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant)),
          if (position != null) ...[
            const SizedBox(height: 2),
            Text(position, style: secondary),
          ],
          const SizedBox(height: 16),
          // Stacked, full width: the inspector is narrow (280-420 px) and both labels must fit.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: () => unawaited(interactions.openDocument(document)),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Open'),
              ),
              const SizedBox(height: 8),
              Tooltip(
                message: 'Open in the right pane, next to what is open',
                child: OutlinedButton.icon(
                  onPressed: () => unawaited(interactions.openBeside(document)),
                  icon: const Icon(Icons.vertical_split_outlined, size: 18),
                  label: const Text('Open beside', maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.outlineVariant),
          const SizedBox(height: 8),
          Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final action in homeDocumentActions(
                    context,
                    recent: recent,
                    interactions: interactions,
                    controller: controller,
                  ))
                    _ActionRow(action: action),
                ],
              )),
          const SizedBox(height: 8),
          Divider(height: 1, color: context.outlineVariant),
          const SizedBox(height: 16),
          _MetaRow(label: 'Last opened', child: Text(dateFormat.format(recent.lastOpenedAt), style: context.bodySmall)),
          _MetaRow(label: 'Modified', child: Text(dateFormat.format(document.modifiedAt), style: context.bodySmall)),
          _MetaRow(label: 'Size', child: Text(formatFileSize(document.sizeBytes), style: context.bodySmall)),
          _MetaRow(
            label: 'Location',
            child: Row(
              children: [
                Expanded(
                  child: Tooltip(
                    key: const ValueKey('home-inspector-location'),
                    message: folder,
                    child: MiddleEllipsisText(folder, style: context.bodySmall),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy location',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () => unawaited(copyToClipboard(folder, 'Location copied')),
                  icon: const Icon(Icons.content_copy_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The preview, at most 160 px tall. A format with no preview (or Hide thumbnails on) gets its
/// small format badge rather than a large empty box.
class _InspectorPreview extends StatefulWidget {
  final RecentDocumentModel recent;

  const _InspectorPreview({required this.recent});

  static const maxHeight = 160.0;
  static const badgeSize = 56.0;

  @override
  State<_InspectorPreview> createState() => _InspectorPreviewState();
}

class _InspectorPreviewState extends State<_InspectorPreview> {
  Future<File?>? _preview;

  @override
  void initState() {
    super.initState();
    final document = widget.recent.document;
    if (document.category != DocumentCategory.unknown) {
      _preview = DocumentThumbnailService.instance.getThumbnail(document, position: widget.recent.readingPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.recent.document;
    final badge = DocumentThumbnail(
      key: const ValueKey('home-inspector-badge'),
      document: document,
      size: _InspectorPreview.badgeSize,
      readingPosition: widget.recent.readingPosition,
    );
    return Obx(() {
      if (ThumbnailPreferences.hidden.value || _preview == null) return badge;
      return FutureBuilder<File?>(
        future: _preview,
        builder: (context, snapshot) {
          final file = snapshot.data;
          if (file == null) return badge;
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _InspectorPreview.maxHeight),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  errorBuilder: (context, error, stackTrace) => badge,
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _ActionRow extends StatelessWidget {
  final HomeDocumentAction action;

  const _ActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final color = action.destructive ? context.error : context.onSurface;
    return HoverSurface(
      key: ValueKey('home-action-${action.label}'),
      onTap: action.onInvoke,
      semanticLabel: action.label,
      builder: (context, states) => AnimatedContainer(
        duration: homeMotion,
        curve: homeCurve,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: states.pressed
              ? context.surfaceContainer
              : (states.hovered ? context.surfaceContainerLow : null),
          borderRadius: BorderRadius.circular(8),
          border: focusRing(context, states),
        ),
        child: Row(
          children: [
            Icon(action.icon, size: 20, color: action.destructive ? color : context.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _MetaRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
