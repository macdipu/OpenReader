import 'package:get/get.dart';

import '../../../core/data/repositories/app_settings_repository_impl.dart';
import '../../../core/data/repositories/document_repository_impl.dart';
import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/error/failure.dart';
import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/recent_document_model.dart';
import '../../../core/domain/repositories/app_settings_repository.dart';
import '../../../core/domain/repositories/document_repository.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../../services/utilities/storage_access_service.dart';
import '../../../app/shell/app_shell_controller.dart';

/// Home screen: category shortcuts, Continue Reading, Recent Documents
/// (BRD 9.3).
class HomeController extends BaseController {
  final DocumentRepository _documentRepository;
  final RecentRepository _recentRepository;
  final StorageAccessService _storageAccess;
  final AppSettingsRepository _settingsRepository;

  HomeController({
    DocumentRepository? documentRepository,
    RecentRepository? recentRepository,
    StorageAccessService? storageAccess,
    AppSettingsRepository? settingsRepository,
  })  : _documentRepository = documentRepository ?? DocumentRepositoryImpl(),
        _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _storageAccess = storageAccess ?? StorageAccessService.instance,
        _settingsRepository = settingsRepository ?? AppSettingsRepositoryImpl();

  /// Continue Reading cards plus the Recent rows below them (UX-12).
  static const _maxRecentPreview = 8;

  /// How many of [recentDocuments] are Continue Reading cards; the rest are
  /// Recent rows, so no document is listed twice.
  static const continueReadingCount = 3;

  bool _retryScan = false;

  Future<void> retry() => _retryScan ? refresh() : load();

  final hasAccess = true.obs;
  final categoryCounts = <DocumentCategory, int>{}.obs;
  final recentDocuments = <RecentDocumentModel>[].obs;

  /// Live "Scan Storage" progress (DESIGN_SPEC #08 FAB) - a real running
  /// found-count from FileScannerService, not a fake percentage.
  final isScanning = false.obs;

  /// Rescans in flight. The auto-scan and a pull-to-refresh can overlap;
  /// the banner stays until the last one ends.
  int _activeScans = 0;
  final scanProgress = 0.obs;

  /// Bumped per [load]/[refresh]; one that finishes after a newer one
  /// started (a tab tap or delete mid-scan) discards its stale result.
  int _loadSession = 0;

  Worker? _readerClosedWorker;

  @override
  void onInit() {
    super.onInit();
    // A reader writes reading history behind Home's back (HOME-RECENTS).
    if (Get.isRegistered<DocumentInteractionController>()) {
      _readerClosedWorker = ever(Get.find<DocumentInteractionController>().readerClosed, (_) => load());
    }
    load();
  }

  @override
  void onClose() {
    _readerClosedWorker?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final session = ++_loadSession;
    _retryScan = false;
    errorMessage.value = null;
    beginLoad();
    hasAccess.value = await _storageAccess.hasAccess();
    if (session != _loadSession) return;
    if (!hasAccess.value) {
      status.value = StateStatus.empty;
      return;
    }

    final failures = await Future.wait([_loadCounts(), _loadRecents()]);
    if (session != _loadSession) return;
    for (final failure in failures) {
      if (failure != null) {
        handleFailure(failure);
        return;
      }
    }
    final isEmpty = categoryCounts.values.every((count) => count == 0) && recentDocuments.isEmpty;
    status.value = isEmpty ? StateStatus.empty : StateStatus.success;

    // One-time auto-scan right after storage access is granted (or on the
    // very first Home load), so a first-run user sees their documents
    // without having to find and tap "Scan Storage" themselves.
    if (isEmpty && !await _settingsRepository.hasAutoScanned() && session == _loadSession) {
      await _settingsRepository.setAutoScanned(true);
      await refresh();
    }
  }

  Future<void> refresh() async {
    final session = ++_loadSession;
    // A Retry from the error screen has nothing to keep mounted, so that
    // case still gets the full-screen spinner.
    beginLoad();
    _activeScans++;
    isScanning.value = true;
    scanProgress.value = 0;
    final result = await _documentRepository.rescan(onProgress: (count) => scanProgress.value = count);
    isScanning.value = --_activeScans > 0;
    await result.fold<Future<void>>(
      (failure) async {
        // A newer load is showing current results; don't replace them.
        if (session != _loadSession) {
          CustomSnackbar.error(failure.message);
          return;
        }
        handleFailure(failure);
        _retryScan = true;
      },
      (_) => load(),
    );
  }

  Future<Failure?> _loadCounts() async {
    final counts = <DocumentCategory, int>{};
    for (final category in DocumentCategory.values
        .where((c) => c != DocumentCategory.unknown)) {
      final result = await _documentRepository.countByCategory(category);
      final failure = result.fold<Failure?>(
        (failure) => failure,
        (count) {
          counts[category] = count;
          return null;
        },
      );
      if (failure != null) return failure;
    }
    categoryCounts.assignAll(counts);
    return null;
  }

  Future<Failure?> _loadRecents() async {
    final result = await _recentRepository.getRecents();
    return result.fold<Failure?>(
      (failure) => failure,
      (list) {
        recentDocuments.assignAll(list.take(_maxRecentPreview).toList());
        return null;
      },
    );
  }

  void openCategory(DocumentCategory category) {
    Get.find<AppShellController>().openFiles(category: category);
  }

  void openAllFiles() {
    Get.find<AppShellController>().openFiles();
  }

  /// "See All" - the reading history lives in Library's History tab (UX-09).
  void openHistory() => Get.find<AppShellController>().openHistory();
}
