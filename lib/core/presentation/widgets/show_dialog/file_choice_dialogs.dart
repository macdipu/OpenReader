import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// What the user picked when a file in Recents could not be found.
enum MissingFileChoice { locate, remove }

/// "This file may have been moved or deleted" with the way out: Locate the file (the picker; its
/// history, favorite and reading position move to it) or Remove it from Recents. A temporary copy of
/// another app's file ([temporaryCopy]) cannot be located: its original is not known, so the dialog
/// says to open it again from that app. Dismissing resolves to null (CR-FILE-RELOCATE).
Future<MissingFileChoice?> showMissingFileDialog({required String name, required bool temporaryCopy}) {
  return Get.dialog<MissingFileChoice>(
    AlertDialog(
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Text(
        temporaryCopy
            ? 'This was a temporary copy from another app. Open it again from that app.'
            : 'This file may have been moved or deleted.',
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        TextButton(onPressed: () => Get.back(result: MissingFileChoice.remove), child: const Text('Remove from Recents')),
        if (!temporaryCopy)
          FilledButton(onPressed: () => Get.back(result: MissingFileChoice.locate), child: const Text('Locate…')),
      ],
    ),
  );
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

/// Asked when the reader of a file another app shared is closed (Android). Dismissing counts as
/// Keep, so nothing is lost by accident.
Future<SharedCopyDecision> showSharedCopyDialog({required String name}) async {
  var remember = false;
  final decision = await Get.dialog<SharedCopyDecision>(
    StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Keep this file?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$name" came from another app, so OpenReader holds a copy of it.'),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              value: remember,
              onChanged: (value) => setState(() => remember = value ?? false),
              title: const Text('Do this every time'),
            ),
          ],
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Get.back(result: SharedCopyDecision(SharedCopyChoice.remove, remember: remember)),
            child: const Text('Remove'),
          ),
          TextButton(
            onPressed: () => Get.back(result: SharedCopyDecision(SharedCopyChoice.saveCopy, remember: remember)),
            child: const Text('Save a copy…'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: SharedCopyDecision(SharedCopyChoice.keep, remember: remember)),
            child: const Text('Keep in OpenReader'),
          ),
        ],
      ),
    ),
  );
  return decision ?? const SharedCopyDecision(SharedCopyChoice.keep);
}
