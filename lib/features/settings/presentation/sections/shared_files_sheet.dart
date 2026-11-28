import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/domain/models/keep_state.dart';
import '../../../../core/presentation/theme/theme_extensions.dart';
import '../settings_controller.dart';

/// Settings > Privacy & data > "Files from other apps": what OpenReader does with the copy it holds of
/// a file another app shared, and how much space those copies use, in one place (CR-FILE-RELOCATE).
class SharedFilesSheet extends StatelessWidget {
  const SharedFilesSheet({super.key, required this.controller});

  final SettingsController controller;

  static const _titles = {
    SharedCopyAction.ask: 'Ask me each time',
    SharedCopyAction.keep: 'Keep in OpenReader',
    SharedCopyAction.remove: 'Remove it',
  };

  static const _details = {
    SharedCopyAction.ask: 'Choose to keep it, save a copy or remove it.',
    SharedCopyAction.keep: 'Stays in Recents until you clear it.',
    SharedCopyAction.remove: 'Deletes the copy and its Recents entry.',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(color: context.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: context.outlineVariant, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: context.primaryContainer, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.folder_copy_outlined, color: context.onPrimaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Files from other apps',
                          style: context.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Obx(
                          () => Text(
                            controller.sharedCopyBytes.value == 0
                                ? 'No copies stored'
                                : '${SettingsController.formatBytes(controller.sharedCopyBytes.value)} stored on this device',
                            style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'When you open a file from another app, such as Gmail or a browser, OpenReader holds a copy '
                'while you read it. Choose what happens to the copy when you close the file.',
                style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(
                'WHEN I CLOSE A FILE',
                style: context.labelSmall?.copyWith(color: context.primary, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Obx(
                () => Column(
                  children: [
                    for (final action in SharedCopyAction.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OptionTile(
                          title: _titles[action]!,
                          detail: _details[action]!,
                          selected: controller.sharedCopyAction.value == action,
                          onTap: () => controller.setSharedCopyAction(action),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 24),
              Obx(() {
                final bytes = controller.sharedCopyBytes.value;
                return OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.error,
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: bytes > 0 ? context.error.withValues(alpha: 0.5) : context.outlineVariant),
                  ),
                  onPressed: bytes > 0 ? controller.clearSharedCopies : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(bytes > 0 ? 'Clear stored copies (${SettingsController.formatBytes(bytes)})' : 'Nothing to clear'),
                );
              }),
              const SizedBox(height: 8),
              Text(
                'Files you kept or marked as favorites stay. The original files are never touched.',
                textAlign: TextAlign.center,
                style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One choice of [SharedFilesSheet]: a card that shows a check when it is the current one.
class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.title, required this.detail, required this.selected, required this.onTap});

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? context.primaryContainer.withValues(alpha: 0.6) : context.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? context.primary : context.outlineVariant, width: selected ? 1.5 : 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(detail, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? context.primary : context.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens [SharedFilesSheet].
Future<void> showSharedFilesSheet(SettingsController controller) =>
    Get.bottomSheet<void>(SharedFilesSheet(controller: controller), isScrollControlled: true, backgroundColor: Colors.transparent);
