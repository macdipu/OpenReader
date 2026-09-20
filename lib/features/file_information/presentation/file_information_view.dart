import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/domain/extensions/extension_export.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_load_error_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import 'file_information_controller.dart';

/// File Metadata & Diagnostics (DESIGN_SPEC.md #11) - BRD 9.16.
class FileInformationView extends GetView<FileInformationController> {
  const FileInformationView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('File Information')),
      body: Obx(() {
        if (controller.status.value.isBusy) return const LoadingView();
        if (controller.status.value.isError) {
          return DocumentLoadErrorView(
            message: controller.errorMessage.value ?? 'This file may have been moved or deleted.',
            onRetry: controller.load,
          );
        }
        final metadata = controller.metadata.value;
        if (metadata == null) return const SizedBox.shrink();

        final document = controller.document;
        final accent = document.category.accentColor(context);
        final tint = document.category.tintColor(context);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Doc identity card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.outlineVariant),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
                    child: Text(document.category.shortCode,
                        style: context.titleSmall?.copyWith(color: accent, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 12),
                  Text(document.displayName, textAlign: TextAlign.center, style: context.titleMedium),
                  const SizedBox(height: 6),
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
              const _AttributeRow(label: 'Created', value: 'Not available'),
              const _AttributeRow(label: 'Page / sheet / slide count', value: 'Not available'),
            ]),
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
        );
      }),
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
