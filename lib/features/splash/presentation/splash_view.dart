import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/presentation/theme/theme_extensions.dart';
import 'splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_copy_outlined, size: 72, color: context.primary),
            const SizedBox(height: 16),
            Text('OpenDocs', style: context.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.primary),
            ),
          ],
        ),
      ),
    );
  }
}
