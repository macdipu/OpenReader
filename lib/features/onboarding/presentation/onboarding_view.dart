import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/platform_info.dart';
import '../../../core/presentation/widgets/storage_privacy_note.dart';
import '../../../core/presentation/utils/storage_access_help.dart';
import '../../../core/presentation/widgets/storage_access_steps.dart';
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
            // The scroll view gives its child loose width, so without the
            // Center + maxWidth the column shrank to its widest child and
            // sat at the left edge on wide desktop windows.
            child: Center(
              child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: max(0, constraints.maxHeight - 48), maxWidth: 480),
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
                      ? 'OpenReader reads PDF, Word, Excel, PowerPoint, CSV, Markdown and text files stored on this device.\n\n'
                          'Tapping Allow Access opens Android\'s "All files access" page. Turn it on for OpenReader so you can '
                          'browse your documents in any folder, not just Downloads or Documents.'
                      : 'OpenReader reads PDF, Word, Excel, PowerPoint, CSV, Markdown and text files stored on this computer.',
                  textAlign: TextAlign.center,
                  style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
                ),
                if (askForAccess) ...[
                  const SizedBox(height: 8),
                  const StoragePrivacyNote(),
                ],
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
                  _DeniedHelp(
                    controller: controller,
                    message: 'Access is blocked. Turn it on in settings.',
                    primaryLabel: 'Open Settings',
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
                      child: _DeniedHelp(
                        controller: controller,
                        message: 'Access was not allowed. Try again.',
                        primaryLabel: 'Allow Access',
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
              ],
            );
              })),
            ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short error line, then the compact steps card for this phone's brand.
class _DeniedHelp extends StatelessWidget {
  final OnboardingController controller;
  final String message;
  final String primaryLabel;
  const _DeniedHelp({required this.controller, required this.message, required this.primaryLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: context.bodyMedium?.copyWith(color: context.error, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: FutureBuilder<StorageAccessHelp>(
            future: controller.accessHelp(primaryLabel: primaryLabel),
            builder: (context, snapshot) {
              final help = snapshot.data;
              return help == null ? const SizedBox(height: 96) : StorageAccessSteps(help: help);
            },
          ),
        ),
      ],
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
