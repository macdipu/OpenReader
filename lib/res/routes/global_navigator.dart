import 'package:flutter/material.dart';

import '../../services/navigation/navigation_service.dart';

/// Convenient accessor for the current root [BuildContext].
///
/// Returns `null` before the app is mounted. Check for `null` before
/// using this in background services or repositories.
///
/// Delegates to [NavigationService.navigatorKey], the key actually passed
/// as `GetMaterialApp.navigatorKey` in `app.dart`. This file previously
/// declared its own separate `rootNavigatorKey`, which was never attached
/// to any widget - every consumer of `rootContext` (`showAppDialog`,
/// `showAppSheet`, `CustomSnackbar.showGlobalToast`, and the standard
/// snackbar helpers' dark-mode detection) was silently getting `null` and
/// no-opping. Found while building the PDF reader's password dialog, which
/// depends on `showAppDialog` actually showing something.
BuildContext? get rootContext => NavigationService.navigatorKey.currentContext;
