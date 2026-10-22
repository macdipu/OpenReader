import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../core/domain/models/document_category.dart';
import '../../features/favorites/presentation/favorites_controller.dart';
import '../../features/files/presentation/files_controller.dart';
import '../../features/home/presentation/home_controller.dart';
import '../../services/platform_integration/incoming_intent_service.dart';
import '../../services/platform_integration/launch_arguments.dart';
import '../../services/utilities/storage_access_service.dart';

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
    if (Get.isRegistered<FilesController>()) {
      final files = Get.find<FilesController>();
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

  Future<void> rescan() => Get.find<HomeController>().refresh();

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

  /// Switches to the Files tab, optionally pre-filtered to [category]
  /// (invoked from Home's category shortcuts, BRD 9.3).
  void openFiles({DocumentCategory? category}) {
    Get.find<FilesController>().selectCategory(category);
    currentIndex.value = filesIndex;
  }
}
