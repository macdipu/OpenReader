import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/platform_info.dart';
import 'onboarding_controller.dart';
import 'dart:math';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
      body: SafeArea(
        // Scrollable but still centred: on a short screen or with large text
        // the content used to overflow and clip (UX-31).
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: max(0, constraints.maxHeight - 48)),
              child: IntrinsicHeight(child: Obx(() {
            final status = controller.status.value;
            // Only Android has a storage permission to ask for; desktop gets a
            // plain welcome with no permission text or Allow button (UX-27).
            final askForAccess = PlatformInfo.isAndroid;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: context.secondaryContainer, borderRadius: BorderRadius.circular(20)),
                  child: Icon(Icons.folder_shared_outlined, size: 48, color: context.secondary),
                ),
                const SizedBox(height: 24),
                Text(
                  'All Your Documents\nin One Reader',
                  textAlign: TextAlign.center,
                  style: context.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  askForAccess
                      ? 'OpenReader reads PDF, Word, Excel, Text, and CSV files stored on this device.\n\n'
                          'Tapping Allow Access requests Android\'s "All Files Access" permission, so you can '
                          'browse your documents in any folder, not just Downloads or Documents.'
                      : 'OpenReader reads PDF, Word, Excel, Text, and CSV files stored on this computer.',
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
                if (!askForAccess)
                  FilledButton(
                    onPressed: controller.continueWithoutAccess,
                    child: const Text('Get started'),
                  )
                else if (status == OnboardingStatus.permanentlyDenied) ...[
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
                if (askForAccess) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: controller.continueWithoutAccess,
                    child: const Text('Not Now'),
                  ),
                ],
              ],
            );
              })),
            ),
          ),
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
