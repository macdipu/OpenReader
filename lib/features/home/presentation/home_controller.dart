import 'package:flutter/widgets.dart' show FocusNode;
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

  /// How much history Home loads: the desktop table lists up to [tableRowLimit] of it and knows
  /// whether there is more; phones show the first [mobilePreviewCount].
  static const _maxRecentLoad = 50;

  /// Phones: Continue Reading cards plus the Recent rows below them (UX-12).
  static const mobilePreviewCount = 8;

  /// Phones: how many of [mobilePreview] are Continue Reading cards; the rest are
  /// Recent rows, so no document is listed twice.
  static const continueReadingCount = 3;

  /// Desktop: Continue reading cards at most, and the rows the Recent files table shows before
  /// "See all" points to Library.
  static const desktopContinueCount = 4;
  static const tableRowLimit = 20;

  /// Desktop inspector width, in logical pixels.
  static const inspectorDefaultWidth = 320.0;
  static const inspectorMinWidth = 280.0;
  static const inspectorMaxWidth = 420.0;

  Future<void> retry() => load();

  final hasAccess = true.obs;
  final recentDocuments = <RecentDocumentModel>[].obs;

  /// The phone feed's share of [recentDocuments].
  List<RecentDocumentModel> get mobilePreview => recentDocuments.take(mobilePreviewCount).toList();

  /// The document shown in the desktop inspector; null shows its empty state.
  final selectedId = RxnString();

  /// Focus for the desktop list pane, so Up / Down / Enter / Delete reach it.
  final listFocus = FocusNode(debugLabel: 'home-list');

  RecentDocumentModel? get selectedRecent {
    final id = selectedId.value;
    if (id == null) return null;
    return recentDocuments.firstWhereOrNull((r) => r.document.id == id);
  }

  void select(String documentId) => selectedId.value = documentId;

  void clearSelection() => selectedId.value = null;

  /// Up / Down in the list pane: moves the selection by [delta] rows of the table as sorted,
  /// staying within it. With nothing selected, Down picks the first row and Up the last.
  void moveSelection(int delta) {
    final rows = tableRows;
    if (rows.isEmpty) return;
    final current = rows.indexWhere((r) => r.document.id == selectedId.value);
    final next = current < 0 ? (delta > 0 ? 0 : rows.length - 1) : (current + delta).clamp(0, rows.length - 1);
    selectedId.value = rows[next].document.id;
  }

  // ---- Desktop: Continue reading and the Recent files table ----

  /// Documents with a saved reading position, most recent first: what there is to continue.
  List<RecentDocumentModel> get continueReading =>
      recentDocuments.where((r) => r.readingPosition.isNotEmpty).take(desktopContinueCount).toList();

  final sortColumn = HomeSortColumn.lastOpened.obs;

  /// Newest first by default; a click on another column starts A-Z (names, types) or largest
  /// first (sizes).
  final sortAscending = false.obs;

  /// A header click: the same column flips the order, another one sorts by it.
  void sortBy(HomeSortColumn column) {
    if (sortColumn.value == column) {
      sortAscending.toggle();
    } else {
      sortColumn.value = column;
      sortAscending.value = column == HomeSortColumn.name || column == HomeSortColumn.type;
    }
  }

  /// [recentDocuments] in the table's order (stable: ties keep history order).
  List<RecentDocumentModel> get sortedRecents {
    final column = sortColumn.value;
    final ascending = sortAscending.value;
    int compare(RecentDocumentModel a, RecentDocumentModel b) => switch (column) {
          HomeSortColumn.name =>
            a.document.displayName.toLowerCase().compareTo(b.document.displayName.toLowerCase()),
          HomeSortColumn.type => a.document.formatLabel.compareTo(b.document.formatLabel),
          HomeSortColumn.size => a.document.sizeBytes.compareTo(b.document.sizeBytes),
          HomeSortColumn.lastOpened => a.lastOpenedAt.compareTo(b.lastOpenedAt),
        };
    final indexed = recentDocuments.indexed.toList()
      ..sort((x, y) {
        final c = ascending ? compare(x.$2, y.$2) : compare(y.$2, x.$2);
        return c != 0 ? c : x.$1.compareTo(y.$1);
      });
    return [for (final (_, r) in indexed) r];
  }

  /// The rows the table shows.
  List<RecentDocumentModel> get tableRows => sortedRecents.take(tableRowLimit).toList();

  /// More history than the table shows: "See all" leads to Library.
  bool get hasMoreRecents => recentDocuments.length > tableRowLimit;

  /// Removes [documentId] from reading history and keeps a neighbouring row selected.
  Future<void> removeFromHistory(String documentId) async {
    final rows = tableRows;
    final index = rows.indexWhere((r) => r.document.id == documentId);
    if (selectedId.value == documentId) {
      final neighbour = index + 1 < rows.length ? index + 1 : index - 1;
      selectedId.value = index >= 0 && neighbour >= 0 && neighbour < rows.length ? rows[neighbour].document.id : null;
    }
    await Get.find<DocumentInteractionController>().removeFromRecent(documentId);
    await load();
  }

  // ---- Desktop: the inspector pane ----

  /// Kept for the session only: no settings key fits it, and the settings repository is not
  /// extended for a pane width.
  final inspectorWidth = inspectorDefaultWidth.obs;

  /// Docked inspector shown (wide windows).
  final inspectorVisible = true.obs;

  /// Overlay drawer open (narrow windows).
  final inspectorOverlayOpen = false.obs;

  void resizeInspector(double width) =>
      inspectorWidth.value = width.clamp(inspectorMinWidth, inspectorMaxWidth).toDouble();

  void resetInspectorWidth() => inspectorWidth.value = inspectorDefaultWidth;

  /// The toolbar button and Ctrl/Cmd+I: shows or hides the docked pane, or the drawer when
  /// the window is too narrow to dock it.
  void toggleInspector({required bool overlay}) {
    if (overlay) {
      inspectorOverlayOpen.toggle();
    } else {
      inspectorVisible.toggle();
    }
  }

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
    listFocus.dispose();
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
        recentDocuments.assignAll(list.take(_maxRecentLoad).toList());
        return null;
      },
    );
  }

  /// "Browse files" - documents are found in the Browse tab now.
  void openBrowse() => Get.find<AppShellController>().openBrowse();

  /// "See All" - the reading history lives in Library's History tab (UX-09).
  void openHistory() => Get.find<AppShellController>().openHistory();

  /// The desktop empty state's "Open a file" (the sidebar's Open file, Ctrl/Cmd+O).
  void pickAndOpenFile() => Get.find<AppShellController>().pickAndOpenFile();
}

/// The desktop Recent files table's sortable columns.
enum HomeSortColumn { name, type, size, lastOpened }
