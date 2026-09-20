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
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: context.secondaryContainer, borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.folder_copy_outlined, size: 36, color: context.secondary),
            ),
            const SizedBox(height: 20),
            Text('OpenReader', style: context.headlineLarge),
            const SizedBox(height: 4),
            Text('100% offline document reader', style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
            const SizedBox(height: 28),
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: context.secondary),
            ),
          ],
        ),
      ),
    );
  }
}
