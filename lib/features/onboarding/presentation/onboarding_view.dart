import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
                Icon(Icons.folder_shared_outlined, size: 96, color: context.primary),
                const SizedBox(height: 24),
                Text(
                  'Access your documents',
                  textAlign: TextAlign.center,
                  style: context.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
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
                const SizedBox(height: 32),
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
