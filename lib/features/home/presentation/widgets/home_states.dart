import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/widgets/key_cap.dart';
import '../../../../core/presentation/widgets/storage_privacy_note.dart';
import 'home_toolbar.dart';

/// Home without storage access (phones; desktop keeps the code path though it has no gate).
class HomePermissionBanner extends StatelessWidget {
  final VoidCallback onRequestAccess;

  const HomePermissionBanner({super.key, required this.onRequestAccess});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_off_outlined, size: 56, color: context.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'OpenReader needs storage access to show your documents.',
              textAlign: TextAlign.center,
              style: context.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRequestAccess, child: const Text('Grant Access')),
            const SizedBox(height: 12),
            const StoragePrivacyNote(),
          ],
        )),
      ),
    );
  }
}

/// Desktop Home with no reading history: what to do next, not just that it is empty.
class HomeDesktopEmptyState extends StatelessWidget {
  final VoidCallback onOpenFile;
  final VoidCallback onBrowse;

  const HomeDesktopEmptyState({super.key, required this.onOpenFile, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: context.surfaceContainerLow, shape: BoxShape.circle),
                child: Icon(Icons.history_rounded, size: 28, color: context.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text('No recent files yet', style: context.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Files you open show up here, so you can pick up where you left off.',
                textAlign: TextAlign.center,
                style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Tonal: the window's primary Open file button is the sidebar's.
                  FilledButton.tonalIcon(
                    onPressed: onOpenFile,
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Open a file'),
                        const SizedBox(width: 8),
                        KeyCap(shortcutLabel('O'), dense: true),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onBrowse,
                    icon: const Icon(Icons.folder_open_outlined, size: 18),
                    label: const Text('Browse your folders'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder rows while history loads, in the table's shape.
class HomeSkeletonRows extends StatelessWidget {
  final int count;

  const HomeSkeletonRows({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: context.surfaceContainerHigh, borderRadius: BorderRadius.circular(4)),
        );
    return Semantics(
      label: 'Loading recent files',
      child: Container(
        key: const ValueKey('home-skeleton'),
        decoration: BoxDecoration(
          color: context.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.outlineVariant),
        ),
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      bar(28, 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(alignment: Alignment.centerLeft, child: bar(120.0 + (i % 3) * 40, 10)),
                      ),
                      bar(64, 10),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
