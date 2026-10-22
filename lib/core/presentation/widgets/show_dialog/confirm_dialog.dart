import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Cancel/confirm dialog shared by delete and clear-history. Resolves to
/// true only when confirmed; dismissing it counts as cancel. [destructive]
/// colours the confirm action with the theme's error colour for actions that
/// can't be undone (CR-OPENREADER-UX UX-15/16).
Future<bool> showConfirmDialog({
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await Get.dialog<bool>(
    Builder(
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(
            style: destructive ? TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error) : null,
            onPressed: () => Get.back(result: true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  return confirmed == true;
}
