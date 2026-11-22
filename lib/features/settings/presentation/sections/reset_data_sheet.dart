import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../settings_controller.dart';

/// Settings > Privacy & data > "Reset & clear data": the two ways to start over in one place.
/// Each choice closes the sheet and then asks for its own confirmation.
class ResetDataSheet extends StatelessWidget {
  const ResetDataSheet({super.key, required this.controller});

  final SettingsController controller;

  void _run(Future<void> Function() action) {
    Get.back<void>();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(color: context.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
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
            Text('Reset & clear data', style: context.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Your documents are never deleted.', style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
            const SizedBox(height: 16),
            _Option(
              icon: Icons.history_rounded,
              title: 'Clear all history',
              detail: 'Removes your recent files.',
              onTap: () => _run(controller.clearHistory),
            ),
            const SizedBox(height: 8),
            _Option(
              icon: Icons.restart_alt_rounded,
              title: 'Reset all settings',
              detail: 'Puts every setting back to its default.',
              destructive: true,
              onTap: () => _run(controller.resetAllSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.title, required this.detail, required this.onTap, this.destructive = false});

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? context.error : context.onPrimaryContainer;
    return Material(
      color: context.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: destructive ? context.error.withValues(alpha: 0.12) : context.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: context.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: destructive ? context.error : null)),
                    const SizedBox(height: 2),
                    Text(detail, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [ResetDataSheet].
Future<void> showResetDataSheet(SettingsController controller) =>
    Get.bottomSheet<void>(ResetDataSheet(controller: controller), isScrollControlled: true, backgroundColor: Colors.transparent);
