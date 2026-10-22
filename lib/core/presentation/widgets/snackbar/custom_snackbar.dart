import 'package:flutter/material.dart';
import 'package:openreader/core/presentation/theme/color_schemes.dart';
import 'package:openreader/core/presentation/utils/screen_utils.dart';
import 'package:openreader/res/routes/app_routes.dart';
import 'package:openreader/res/routes/global_navigator.dart';
import 'package:get/get.dart';

enum SnackbarType {
  success,
  error,
  warning,
  info,
}

class CustomSnackbar {
  /// Resolves the current brightness from the root context, defaulting to
  /// light when the app hasn't mounted yet (e.g. a very early background call).
  static bool get _isDark =>
      rootContext != null && Theme.of(rootContext!).brightness == Brightness.dark;

  static Color _pick(AdaptiveColor c) => _isDark ? c.dark : c.light;

  /// Height of the shell's compact bottom navigation bar (app_shell.dart),
  /// which a bottom snackbar must clear rather than cover (UX-28).
  static const double _bottomNavHeight = 64;

  /// [title] is optional: it's shown only when it says something the message
  /// doesn't (e.g. the file name) - never a generic "Success"/"Error" (UX-28).
  static void show({
    String? title,
    required String message,
    required SnackbarType type,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final (backgroundColor, textColor, icon) = switch (type) {
      SnackbarType.success => (_pick(AppColors.success), _pick(AppColors.onSuccess), Icons.check_circle_outline),
      SnackbarType.error => (_pick(AppColors.error), _pick(AppColors.onError), Icons.error_outline),
      SnackbarType.warning => (_pick(AppColors.warning), _pick(AppColors.onWarning), Icons.warning_amber_outlined),
      SnackbarType.info => (_pick(AppColors.info), _pick(AppColors.onInfo), Icons.info_outline),
    };

    final context = rootContext;
    final overNav = context != null && Get.currentRoute == AppRoutes.appShell && ScreenUtils.of(context).isCompact;

    Get.snackbar(
      title ?? '',
      message,
      titleText: title == null ? const SizedBox.shrink() : null,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: backgroundColor,
      colorText: textColor,
      icon: Icon(icon, color: textColor),
      duration: duration,
      // The nav bar grows with text size (scaledExtent), so must the gap.
      margin: EdgeInsets.fromLTRB(16, 16, 16, 16 + (overNav ? context.scaledExtent(_bottomNavHeight) : 0)),
      borderRadius: 12,
      isDismissible: true,
      dismissDirection: DismissDirection.horizontal,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeInBack,
      animationDuration: const Duration(milliseconds: 300),
      // No blur/dim: a status message shouldn't obscure the screen (UX-28).
      overlayBlur: 0,
      mainButton: onAction == null
          ? null
          : TextButton(
              onPressed: () {
                Get.closeCurrentSnackbar();
                onAction();
              },
              child: Text(actionLabel ?? '', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
            ),
      snackbarStatus: (status) {
        if (status == SnackbarStatus.CLOSED) {
          // Snackbar closed
        }
      },
    );
  }

  static void success(String message, {String? title}) {
    show(
      title: title,
      message: message,
      type: SnackbarType.success,
    );
  }

  static void error(String message, {String? title, String? actionLabel, VoidCallback? onAction}) {
    show(
      title: title,
      message: message,
      type: SnackbarType.error,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void warning(String message, {String? title}) {
    show(
      title: title,
      message: message,
      type: SnackbarType.warning,
    );
  }

  static void info(String message, {String? title}) {
    show(
      title: title,
      message: message,
      type: SnackbarType.info,
    );
  }

  static void showGlobalToast({
    required String message,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    String? status,
  }) {
    final context = rootContext;
    if (context == null) {
      return;
    }

    final backgroundColor = _toastBackgroundColor(status);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: action,
        backgroundColor: backgroundColor,
      ),
    );
  }

  static Color? _toastBackgroundColor(String? status) {
    switch (status) {
      case 'success':
        return _pick(AppColors.success);
      case 'error':
        return _pick(AppColors.error);
      case 'warning':
        return _pick(AppColors.warning);
      case 'info':
        return _pick(AppColors.info);
      default:
        return null;
    }
  }
}
