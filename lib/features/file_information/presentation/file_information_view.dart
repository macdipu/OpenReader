import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/domain/extensions/extension_export.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_load_error_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import 'file_information_controller.dart';

/// File Metadata & Diagnostics (DESIGN_SPEC.md #11) - BRD 9.16.
///
/// Presented as a modal bottom sheet (per spec: "rounded-t-3xl, scrim
/// backdrop, drag handle, close(X) button - no bottom nav"), not a pushed
/// route. Call [showFileInformationSheet] rather than navigating directly.
Future<void> showFileInformationSheet(BuildContext context, DocumentModel document) {
  Get.put(FileInformationController(document: document));
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const FileInformationSheet(),
  ).whenComplete(() => Get.delete<FileInformationController>());
}

class FileInformationSheet extends GetView<FileInformationController> {
  const FileInformationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        // Deliberately NOT `mainAxisSize: min`: this Column mixes a fixed
        // header with a `Flexible` scrollable body, and `min` starves the
        // Flexible of bounded space to size against, which is what caused
        // the body to overflow past the sheet's max-height instead of
        // scrolling internally.
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: context.outlineVariant, borderRadius: BorderRadius.circular(999))),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: context.surfaceContainerLow, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.fact_check_outlined, color: context.secondary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('File Information & Diagnostics', style: context.titleMedium),
                        Text(
                          'Sandboxed local document inspector',
                          style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            const Divider(height: 20),
            Flexible(
              child: Obx(() {
                if (controller.status.value.isBusy) {
                  return const Padding(padding: EdgeInsets.all(32), child: LoadingView());
                }
                if (controller.status.value.isError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: DocumentLoadErrorView(
                      message: controller.errorMessage.value ?? 'This file may have been moved or deleted.',
                      onRetry: controller.load,
                    ),
                  );
                }
                final metadata = controller.metadata.value;
                if (metadata == null) return const SizedBox.shrink();

                final document = controller.document;
                final accent = document.category.accentColor(context);
                final tint = document.category.tintColor(context);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Doc identity card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: tint,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: accent.withValues(alpha: 0.3)),
                              ),
                              child: Text(document.category.shortCode,
                                  style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.titleSmall),
                                  Text(
                                    '${formatFileSize(metadata.sizeBytes)} • ${metadata.modifiedAt.toDMYString()}',
                                    style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.tertiaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.verified_outlined, size: 12, color: context.tertiary),
                                const SizedBox(width: 4),
                                Text('Local Only', style: context.monoMetadata.copyWith(color: context.tertiary)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('SYSTEM ATTRIBUTES', style: context.labelLarge?.copyWith(color: context.onSurfaceVariant, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      _AttributeCard(children: [
                        _AttributeRow(
                          label: 'Storage Location',
                          value: metadata.path,
                          mono: true,
                          trailing: IconButton(
                            icon: Icon(Icons.copy_rounded, size: 18, color: context.onSurfaceVariant),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: metadata.path));
                              CustomSnackbar.success('Path copied to clipboard.');
                            },
                          ),
                        ),
                        _AttributeRow(label: 'Format', value: metadata.category.label),
                        _AttributeRow(label: 'Physical Size', value: formatFileSize(metadata.sizeBytes)),
                        _AttributeRow(label: 'Last Modified', value: metadata.modifiedAt.toDMYString()),
                        const _AttributeRow(
                          label: 'Access Permissions',
                          value: 'Read/write within OpenReader\'s sandboxed storage scope',
                        ),
                        const _AttributeRow(label: 'Created', value: 'Not available'),
                        const _AttributeRow(label: 'Page / sheet / slide count', value: 'Not available'),
                      ]),
                      const SizedBox(height: 20),
                      Text('ENGINE DIAGNOSTICS', style: context.labelLarge?.copyWith(color: context.onSurfaceVariant, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.tertiaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: context.tertiary, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Offline document read verified - no network access used',
                                style: context.bodySmall?.copyWith(color: context.onSurface),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Obx(() => _ActionButton(
                                icon: controller.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                                label: controller.isFavorite ? 'Unfavorite' : 'Favorite',
                                onTap: controller.toggleFavorite,
                              )),
                          _ActionButton(icon: Icons.share_outlined, label: 'Share', onTap: controller.share),
                          _ActionButton(icon: Icons.open_in_new_rounded, label: 'Open With', onTap: controller.openWith),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttributeCard extends StatelessWidget {
  final List<Widget> children;
  const _AttributeCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 1, color: context.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final Widget? trailing;

  const _AttributeRow({required this.label, required this.value, this.mono = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: mono ? context.monoMetadata.copyWith(color: context.onSurface) : context.bodyMedium,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
        const SizedBox(height: 4),
        Text(label, style: context.labelSmall),
      ],
    );
  }
}
