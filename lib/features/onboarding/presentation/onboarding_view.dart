import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import 'onboarding_controller.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            final status = controller.status.value;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.tertiaryContainer.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.16 : 1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shield_outlined, size: 14, color: context.tertiary),
                    const SizedBox(width: 6),
                    Text('100% OFFLINE', style: context.monoMetadata.copyWith(color: context.tertiary)),
                  ]),
                ),
                const SizedBox(height: 24),
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                  child: Icon(Icons.folder_shared_outlined, size: 48, color: context.secondary),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your Documents, Completely\nPrivate & Offline',
                  textAlign: TextAlign.center,
                  style: context.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'OpenReader reads PDF, Word, Excel, PowerPoint, Text, and CSV files stored on '
                  'this device. Nothing is uploaded — everything stays local and works offline.\n\n'
                  'Tapping Allow Access requests Android\'s "All Files Access" permission, since your '
                  'documents can be in any folder, not just Downloads or Documents.',
                  textAlign: TextAlign.center,
                  style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final format in DocumentCategory.values.where((c) => c != DocumentCategory.unknown))
                      _FormatPill(category: format),
                  ],
                ),
                const SizedBox(height: 28),
                if (status == OnboardingStatus.permanentlyDenied) ...[
                  Text(
                    'Storage access was permanently denied. Open Settings to allow it.',
                    textAlign: TextAlign.center,
                    style: context.bodyMedium?.copyWith(color: context.error),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: controller.openSettings,
                    child: const Text('Open Settings'),
                  ),
                ] else ...[
                  if (status == OnboardingStatus.denied)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'Access was denied. You can try again or continue in limited mode.',
                        textAlign: TextAlign.center,
                        style: context.bodyMedium?.copyWith(color: context.error),
                      ),
                    ),
                  FilledButton(
                    onPressed: status == OnboardingStatus.requesting ? null : controller.allowAccess,
                    child: status == OnboardingStatus.requesting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Allow Access'),
                  ),
                ],
                const SizedBox(height: 12),
                TextButton(
                  onPressed: controller.continueWithoutAccess,
                  child: const Text('Not Now'),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _FormatPill extends StatelessWidget {
  final DocumentCategory category;
  const _FormatPill({required this.category});

  @override
  Widget build(BuildContext context) {
    final accent = category.accentColor(context);
    final tint = category.tintColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Text(category.shortCode, style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800)),
    );
  }
}
