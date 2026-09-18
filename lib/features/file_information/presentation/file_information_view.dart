import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/extensions/extension_export.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/document/document_load_error_view.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import 'file_information_controller.dart';

/// BRD 9.16 File Information screen (ODF-010).
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

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  Icon(controller.document.category.icon, size: 64, color: context.primary),
                  const SizedBox(height: 12),
                  Text(
                    controller.document.displayName,
                    textAlign: TextAlign.center,
                    style: context.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _InfoRow(label: 'Path', value: metadata.path),
            _InfoRow(label: 'Category', value: metadata.category.label),
            _InfoRow(label: 'Size', value: formatFileSize(metadata.sizeBytes)),
            _InfoRow(label: 'Modified', value: metadata.modifiedAt.toDMYString()),
            // BRD 9.16 corner case "Metadata unavailable": these two fields
            // need a creation-time API and a reader's own parser, neither of
            // which exists yet - shown explicitly rather than guessed.
            const _InfoRow(label: 'Created', value: 'Not available'),
            const _InfoRow(label: 'Page/sheet/slide count', value: 'Not available'),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Obx(() => _ActionButton(
                      icon: controller.isFavorite ? Icons.favorite : Icons.favorite_border,
                      label: controller.isFavorite ? 'Remove Favorite' : 'Add Favorite',
                      onTap: controller.toggleFavorite,
                    )),
                _ActionButton(icon: Icons.share_outlined, label: 'Share', onTap: controller.share),
                _ActionButton(icon: Icons.open_in_new, label: 'Open With', onTap: controller.openWith),
              ],
            ),
          ],
        );
      }),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: context.bodyMedium)),
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
        IconButton(onPressed: onTap, icon: Icon(icon)),
        Text(label, style: context.labelSmall),
      ],
    );
  }
}
