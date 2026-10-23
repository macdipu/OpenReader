import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/domain/models/document_category.dart';
import '../../features/favorites/presentation/favorites_controller.dart';
import '../../features/browse/presentation/browse_controller.dart';
import '../../features/home/presentation/home_controller.dart';
import '../../services/platform_integration/incoming_intent_service.dart';
import '../../services/platform_integration/launch_arguments.dart';
import '../../services/utilities/storage_access_service.dart';
import '../../core/presentation/widgets/snackbar/custom_snackbar.dart';

class AppShellController extends GetxController with WidgetsBindingObserver {
  static const homeIndex = 0;
  static const filesIndex = 1;
  static const favoritesIndex = 2;

  final RxInt currentIndex = homeIndex.obs;

  final IncomingIntentService _incomingIntentService;
  final StorageAccessService _storageAccess;

  AppShellController({IncomingIntentService? incomingIntentService, StorageAccessService? storageAccess})
      : _incomingIntentService = incomingIntentService ?? IncomingIntentService(),
        _storageAccess = storageAccess ?? StorageAccessService.instance;

  @override
  void onInit() {
    super.onInit();
    // BRD §7.7 / TASK-009: by the time the shell exists, onboarding/storage
    // access has already been resolved, so it's safe to start listening for
    // an incoming file here.
    unawaited(_incomingIntentService.init());
    _openLaunchFiles();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Storage access can change while the app is in the background (the
  /// user granted it from system settings after "Grant Access" sent them
  /// there, or revoked it) - nothing else re-checks it (UX-18).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_recheckStorageAccess());
  }

  Future<void> _recheckStorageAccess() async {
    final access = await _storageAccess.hasAccess();
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      if (home.hasAccess.value != access) unawaited(home.load());
    }
    if (Get.isRegistered<BrowseController>()) {
      final files = Get.find<BrowseController>();
      if (files.hasAccess.value != access) unawaited(files.load());
    }
  }

  /// Desktop: a file passed on the command line when the app was launched.
  void _openLaunchFiles() {
    final files = LaunchArguments.take();
    if (files.isNotEmpty) unawaited(_incomingIntentService.handlePath(files.first));
  }

  /// "Open file" - lets desktop users read a document outside the scanned
  /// folders (and phones one outside shared storage).
  Future<void> pickAndOpenFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: DocumentCategory.supportedExtensions,
    );
    final path = result?.files.single.path;
    if (path != null) await _incomingIntentService.handlePath(path);
  }


  /// A file is being dragged over the window (desktop drop target, UX-34).
  final isDraggingFile = false.obs;

  /// Files dropped onto the window (ADR-OPENREADER-desktop-drop): the first
  /// one goes through the same open path as "Open file" and launch arguments,
  /// so format checks and messages are shared.
  Future<void> openDroppedPaths(List<String> paths) async {
    isDraggingFile.value = false;
    if (paths.isEmpty) return;
    await _incomingIntentService.handlePath(paths.first);
    if (paths.length > 1) CustomSnackbar.info('Opened the first of ${paths.length} files.');
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingIntentService.dispose();
    super.onClose();
  }

  void changeTab(int index) {
    currentIndex.value = index;
    // Belt-and-suspenders reload on tab select: verified on a real device
    // that FavoritesController's own `ever(...favoriteIds...)` reactive
    // subscription (favorites_controller.dart) does not reliably pick up a
    // favorite toggled from a different screen (e.g. Files' context menu)
    // once the Favorites tab has already been visited once this session —
    // the database write succeeds but the tab keeps showing its old list
    // until this. Root cause in the reactive chain itself wasn't isolated
    // further; reloading on every tab-select is small and guaranteed
    // correct regardless of it.
    if (index == favoritesIndex) {
      Get.find<FavoritesController>().load();
    }
    // Same reasoning as above, for Home's Recent Documents/Continue Reading
    // list: Settings > "Clear Recent History" and Favorites' History tab
    // both clear via their own RecentRepository call without notifying
    // Home's separate `recentDocuments` list, which would otherwise show a
    // stale (already-deleted) history until the app restarts.
    if (index == homeIndex) {
      Get.find<HomeController>().load();
    }
  }

  /// Home's "See All": Library tab, History sub-tab (UX-09 - the only
  /// reading-history screen now).
  void openHistory() {
    changeTab(favoritesIndex);
    Get.find<FavoritesController>().showHistory();
  }

  /// Switches to the Browse tab (Home's "Browse files").
  void openBrowse() => currentIndex.value = filesIndex;

  /// Search screen's "Search on device": Browse tab, searching the folder
  /// it's in (or all storage) for [query].
  void searchOnDevice(String query) {
    openBrowse();
    unawaited(Get.find<BrowseController>().searchSubfolders(query));
  }
}
