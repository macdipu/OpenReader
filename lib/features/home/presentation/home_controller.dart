import 'package:get/get.dart';

import '../../../core/data/repositories/recent_repository_impl.dart';
import '../../../core/domain/error/failure.dart';
import '../../../core/domain/models/recent_document_model.dart';
import '../../../core/domain/repositories/recent_repository.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../services/utilities/storage_access_service.dart';
import '../../../app/shell/app_shell_controller.dart';

/// Home screen: Continue Reading and Recent Documents (BRD 9.3), plus the
/// way into the Browse tab.
class HomeController extends BaseController {
  final RecentRepository _recentRepository;
  final StorageAccessService _storageAccess;

  HomeController({
    RecentRepository? recentRepository,
    StorageAccessService? storageAccess,
  })  : _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _storageAccess = storageAccess ?? StorageAccessService.instance;

  /// Continue Reading cards plus the Recent rows below them (UX-12).
  static const _maxRecentPreview = 8;

  /// How many of [recentDocuments] are Continue Reading cards; the rest are
  /// Recent rows, so no document is listed twice.
  static const continueReadingCount = 3;

  Future<void> retry() => load();

  final hasAccess = true.obs;
  final recentDocuments = <RecentDocumentModel>[].obs;

  /// The document shown in the details pane on wide windows; null means the
  /// most recent one.
  final selectedId = RxnString();

  RecentDocumentModel? get selectedRecent {
    if (recentDocuments.isEmpty) return null;
    final id = selectedId.value;
    return recentDocuments.firstWhereOrNull((r) => r.document.id == id) ?? recentDocuments.first;
  }

  void select(String documentId) => selectedId.value = documentId;

  /// Bumped per [load]; one that finishes after a newer one started (a tab
  /// tap or a delete) discards its stale result.
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
    errorMessage.value = null;
    beginLoad();
    hasAccess.value = await _storageAccess.hasAccess();
    if (session != _loadSession) return;
    if (!hasAccess.value) {
      status.value = StateStatus.empty;
      return;
    }

    // No storage scan (CR-OPENREADER-BROWSE): Home shows reading history;
    // documents are found from the Browse tab.
    final failure = await _loadRecents();
    if (session != _loadSession) return;
    if (failure != null) {
      handleFailure(failure);
      return;
    }
    status.value = recentDocuments.isEmpty ? StateStatus.empty : StateStatus.success;
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

  /// "Browse files" - documents are found in the Browse tab now.
  void openBrowse() => Get.find<AppShellController>().openBrowse();

  /// "See All" - the reading history lives in Library's History tab (UX-09).
  void openHistory() => Get.find<AppShellController>().openHistory();
}
