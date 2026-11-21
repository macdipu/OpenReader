import 'package:flutter/material.dart';

import '../../../services/utilities/url_launcher_service.dart';
import '../theme/theme_extensions.dart';
import 'snackbar/custom_snackbar.dart';

const privacyPolicyUrl = 'https://macdipu.github.io/OpenReader/privacy.html';

/// Why OpenReader asks for file access, and that nothing leaves the device. Shown with the access
/// request (onboarding, Home), with a link to the privacy policy.
class StoragePrivacyNote extends StatelessWidget {
  /// Opens the policy; tests replace it. Defaults to the system browser with an error snackbar.
  final Future<void> Function()? onOpenPolicy;
  const StoragePrivacyNote({super.key, this.onOpenPolicy});

  static const purpose = 'OpenReader asks for file access only to find and open your documents. '
      'Files are read on this device and never uploaded or shared.';

  static Future<void> openPolicy() async {
    final result = await UrlLauncherService.instance.launch(privacyPolicyUrl);
    if (result.isLeft()) CustomSnackbar.error('Could not open the privacy policy.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          purpose,
          textAlign: TextAlign.center,
          style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
        ),
        TextButton(
          key: const ValueKey('privacy-policy-link'),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onOpenPolicy ?? openPolicy,
          child: const Text('Privacy policy'),
        ),
      ],
    );
  }
}
