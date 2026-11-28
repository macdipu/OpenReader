import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../domain/models/document_model.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/file_size_formatter.dart';

/// Tells the user a file in Recents is gone (moved or deleted) and that its entry was removed from
/// Recents. A file that can be found again offers Locate: the picker, and its favorite and reading
/// position move to the file chosen. A temporary copy of another app's file (`temporaryCopy`) cannot be
/// located, so the dialog only says to open it again from that app. Resolves to true for Locate
/// (CR-FILE-RELOCATE).
Future<bool> showMissingFileDialog({required String name, required bool temporaryCopy}) async {
  final locate = await Get.dialog<bool>(
    AlertDialog(
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            temporaryCopy
                ? 'This was a temporary copy from another app. Open it again from that app.'
                : 'This file may have been moved or deleted.',
          ),
          const SizedBox(height: 8),
          const Text('It was removed from Recents.'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: Text(temporaryCopy ? 'OK' : 'Close')),
        if (!temporaryCopy) FilledButton(onPressed: () => Get.back(result: true), child: const Text('Locate…')),
      ],
    ),
  );
  return locate == true;
}

/// What to do with the copy of a file another app shared, once its reader is closed.
enum SharedCopyChoice { keep, saveCopy, remove }

/// The user's answer: [choice], and [remember] to make it the setting so the question is not asked
/// again.
class SharedCopyDecision {
  const SharedCopyDecision(this.choice, {this.remember = false});

  final SharedCopyChoice choice;
  final bool remember;
}

/// Asked when the reader of a file another app shared is closed (Android): a bottom sheet, within thumb
/// reach, with the file at the top, one clear main action and the two others quieter. Swiping it away
/// or tapping outside counts as Keep, so nothing is lost by accident.
Future<SharedCopyDecision> showSharedCopyDialog({required DocumentModel document}) async {
  final decision = await Get.bottomSheet<SharedCopyDecision>(
    SharedCopySheet(document: document),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
  return decision ?? const SharedCopyDecision(SharedCopyChoice.keep);
}

/// The content of [showSharedCopyDialog].
class SharedCopySheet extends StatefulWidget {
  const SharedCopySheet({super.key, required this.document});

  final DocumentModel document;

  @override
  State<SharedCopySheet> createState() => _SharedCopySheetState();
}

class _SharedCopySheetState extends State<SharedCopySheet> {
  bool _remember = false;

  void _choose(SharedCopyChoice choice) => Get.back(result: SharedCopyDecision(choice, remember: _remember));

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final accent = document.category.accentColor(context);
    final tint = document.category.tintColor(context);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: context.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    document.badgeCode,
                    style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatFileSize(document.sizeBytes)} · from another app',
                        style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'OpenReader holds a copy of this file. Keep it to find it again in Recents, or remove it.',
              style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () => _choose(SharedCopyChoice.keep),
              icon: const Icon(Icons.bookmark_added_outlined),
              label: const Text('Keep in OpenReader'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () => _choose(SharedCopyChoice.saveCopy),
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Save a copy…'),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: context.error,
                minimumSize: const Size.fromHeight(46),
              ),
              onPressed: () => _choose(SharedCopyChoice.remove),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove'),
            ),
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _remember,
              onChanged: (value) => setState(() => _remember = value),
              title: Text('Do this every time', style: context.bodyMedium),
              subtitle: Text(
                'Change it later in Settings > Privacy & data.',
                style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
