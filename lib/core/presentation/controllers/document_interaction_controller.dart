import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/repositories/document_repository_impl.dart';
import '../../data/repositories/favorite_repository_impl.dart';
import '../../data/repositories/recent_repository_impl.dart';
import '../../domain/models/document_model.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/repositories/favorite_repository.dart';
import '../../domain/repositories/recent_repository.dart';
import 'file_relocation.dart';
import '../widgets/show_dialog/confirm_dialog.dart';
import '../widgets/snackbar/custom_snackbar.dart';
import '../../../services/utilities/app_private_paths.dart';
import '../../../services/utilities/storage_access_service.dart';
import '../utils/storage_access_flow.dart';
import '../../domain/models/document_category.dart';
import '../../../features/workspace/presentation/workspace_controller.dart';
import '../../../res/routes/app_routes.dart';
import '../utils/platform_info.dart';

/// Cross-screen document actions (favorite toggling, opening, sharing, Open
/// With, and File Information's accessibility guard) and the single reactive
/// source of truth for favorite state, shared by Home, Files, Search,
/// Recents, and Favorites so a change made on one screen is reflected on the
/// others immediately.
class DocumentInteractionController extends GetxController {
  final FavoriteRepository _favoriteRepository;
  final RecentRepository _recentRepository;
  final DocumentRepository _documentRepository;
  final StorageAccessService _storageAccess;
  final AppPrivatePaths _privatePaths;

  DocumentInteractionController({
    FavoriteRepository? favoriteRepository,
    RecentRepository? recentRepository,
    DocumentRepository? documentRepository,
    StorageAccessService? storageAccess,
    AppPrivatePaths? privatePaths,
    FileRelocation? relocation,
  })  : _favoriteRepository = favoriteRepository ?? FavoriteRepositoryImpl(),
        _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _documentRepository = documentRepository ?? DocumentRepositoryImpl(),
        _storageAccess = storageAccess ?? StorageAccessService.instance,
        _privatePaths = privatePaths ?? AppPrivatePaths.instance {
    _relocation = relocation ??
        FileRelocation(documents: _documentRepository, recents: _recentRepository, privatePaths: _privatePaths);
  }

  /// Moved or deleted files, and copies of other apps' files (CR-FILE-RELOCATE).
  late final FileRelocation _relocation;

  final favoriteIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    refreshFavoriteIds();
  }

  Future<void> refreshFavoriteIds() async {
    final result = await _favoriteRepository.getFavorites();
    result.fold(
      (_) {},
      (documents) => favoriteIds.assignAll(documents.map((d) => d.id)),
    );
  }

  bool isFavorite(String documentId) => favoriteIds.contains(documentId);

  Future<void> toggleFavorite(String documentId) async {
    final wasFavorite = favoriteIds.contains(documentId);
    // Optimistic update; reconciled with the repository result below.
    if (wasFavorite) {
      favoriteIds.remove(documentId);
    } else {
      favoriteIds.add(documentId);
    }

    final result = await _favoriteRepository.toggle(documentId);
    result.fold(
      (failure) {
        // Revert on failure (BRD favorites must persist reliably).
        if (wasFavorite) {
          favoriteIds.add(documentId);
        } else {
          favoriteIds.remove(documentId);
        }
        CustomSnackbar.error(failure.message);
      },
      (_) {},
    );
  }

  /// Hands off to the matching reader, recording the open in Recent History.
  /// Each reader owns its own `markOpened` calls (initial restore + debounced persistence), so this
  /// does not call it for them - a bare `markOpened(id)` here would reset an
  /// existing reading position back to `{}`, since it defaults to an empty
  /// map and replaces the whole row.
  ///
  /// [fromOtherApp] is for a file another app handed to OpenReader (BRD §7.7):
  /// it is a copy in OpenReader's own cache, readable without the storage
  /// permission, so that permission check is skipped for it.
  Future<void> openDocument(DocumentModel document, {bool fromOtherApp = false}) async {
    if (!await _verifyStillAccessible(document, skipAccessCheck: fromOtherApp)) return;
    switch (document.category) {
      case DocumentCategory.pdf:
        await _openReader(AppRoutes.pdfReader, document);
        return;
      case DocumentCategory.word:
        await _openReader(AppRoutes.wordReader, document);
        return;
      case DocumentCategory.excel:
        await _openReader(AppRoutes.excelReader, document);
        return;
      case DocumentCategory.text:
        await _openReader(AppRoutes.textReader, document);
        return;
      case DocumentCategory.csv:
        await _openReader(AppRoutes.csvReader, document);
        return;
      case DocumentCategory.powerpoint:
        await _openReader(AppRoutes.powerpointReader, document);
        return;
      case DocumentCategory.unknown:
        CustomSnackbar.info('This file type is not supported.', title: document.displayName);
        return;
    }
  }

  /// Bumped once a reader has closed and its final reading-position save
  /// has landed. Home and the History tab listen to it to pick up that
  /// history (CR-OPENREADER-UX HOME-RECENTS) - nothing else reloads them on
  /// return.
  final readerClosed = 0.obs;

  /// Each reader's `onClose` hands over its final save ([save], or null when
  /// there is nothing to save). Not bumped on route pop: the reader's
  /// `onClose` runs after the pop transition, so a reload on pop would read
  /// history before that save.
  ///
  /// [documentId] names the reader's document so a replacement waits for that reader's disposal, not
  /// for any other reader's save.
  void readerClosedAfter(Future<Object?>? save, {String? documentId}) {
    void done() {
      readerClosed.value++;
      if (!_closedIds.isClosed) _closedIds.add(documentId);
      // A copy of another app's file: ask what to do with it now that the reader is gone.
      unawaited(_relocation.onReaderClosed(documentId, onChanged: () => readerClosed.value++));
    }

    if (save == null) {
      done();
    } else {
      unawaited(save.whenComplete(done));
    }
  }

  final _closedIds = StreamController<String?>.broadcast();

  @override
  void onClose() {
    unawaited(_closedIds.close());
    super.onClose();
  }

  /// Opens [document] in the right-hand pane next to what is open (wide windows only; elsewhere it
  /// just opens). The document keeps its own tab, so closing the side leaves it open.
  Future<void> openBeside(DocumentModel document) async {
    final workspace = Get.isRegistered<WorkspaceController>() ? Get.find<WorkspaceController>() : null;
    if (workspace == null || !workspace.enabled) return openDocument(document);
    if (!await _verifyStillAccessible(document)) return;
    unawaited(_recordOpen(document));
    Get.until((route) => route.isFirst || route.settings.name == AppRoutes.appShell);
    if (!workspace.openBeside(document)) {
      CustomSnackbar.info('Close a tab to open another document (up to ${WorkspaceController.maxTabs}).');
    }
  }

  /// On wide windows a document opens as a tab (or beside another) instead of replacing the screen.
  /// Returns false when the workspace is off (phones, narrow windows), so the caller pushes the route.
  bool _openInWorkspace(DocumentModel document) {
    if (!Get.isRegistered<WorkspaceController>()) return false;
    final workspace = Get.find<WorkspaceController>();
    if (!workspace.enabled) return false;
    // Search and similar pages sit on top of the shell: come back to it first.
    Get.until((route) => route.isFirst || route.settings.name == AppRoutes.appShell);
    if (!workspace.open(document)) {
      CustomSnackbar.info('Close a tab to open another document (up to ${WorkspaceController.maxTabs}).');
    }
    return true;
  }

  /// Opens that replace an open reader run one after another, so two quick opens never both pop the
  /// open reader (the second would pop the shell); the latest document ends up shown.
  Future<void>? _openChain;

  /// Document id of the reader this controller last pushed (null when unknown).
  String? _pushedDocumentId;

  Future<void> _openReader(String route, DocumentModel document) async {
    unawaited(_recordOpen(document));
    if (_openInWorkspace(document)) return;
    final previous = _openChain;
    final turn = Completer<void>();
    _openChain = turn.future;
    try {
      if (previous != null) await previous;
      await _replaceAndPush(route, document);
    } finally {
      turn.complete();
    }
  }

  Future<void> _replaceAndPush(String route, DocumentModel document) async {
    // Get.toNamed ignores a push of the route that is already on top (preventDuplicates), so a second
    // document of the same reader type arriving while one is open would be dropped. Replacing the
    // route in place (offNamed) would let the old route's disposal delete the new reader's controller
    // (same type, same key), so close the open reader first, let it dispose, then push. A different
    // reader type pushes on top as usual.
    if (Get.currentRoute == route) {
      // The reader being closed reports through [readerClosedAfter] once disposed; the timeout only
      // guards a reader that never does.
      final closing = _pushedDocumentId;
      final disposed = _closedIds.stream
          .firstWhere((id) => closing == null || id == closing)
          .then<void>((_) {})
          .timeout(const Duration(seconds: 2), onTimeout: () {});
      if (Get.currentRoute == route) Get.back<void>();
      await disposed;
    }
    _pushedDocumentId = document.id;
    unawaited(Get.toNamed(route, arguments: document));
  }

  /// Every open lands in History - a double-clicked file, an Android intent,
  /// the picker, a drop - not just ones the reader later saves a position for
  /// (some readers only save once the user has scrolled). Indexed first:
  /// history rows reference index rows. Never blocks or fails the open.
  Future<void> _recordOpen(DocumentModel document) async {
    try {
      await _documentRepository.indexDocument(document);
      await _recentRepository.touch(document.id);
    } catch (_) {
      // History is best-effort.
    }
  }

  /// Opens a document picked in the in-app browser. Browsed files aren't in
  /// the index until used (CR-OPENREADER-BROWSE), and recents/favorites
  /// reference index rows, so it's indexed first.
  Future<void> openFromBrowse(DocumentModel document) async {
    final indexed = await _documentRepository.indexDocument(document);
    // Still open it - just say it won't appear in Recent.
    indexed.fold((failure) => CustomSnackbar.error("This document won't appear in Recent.", title: document.displayName), (_) {});
    await openDocument(document);
  }

  /// Star/unstar from the browser - indexed first, for the same reason.
  Future<void> toggleFavoriteFor(DocumentModel document) async {
    if (!isFavorite(document.id)) await _documentRepository.indexDocument(document);
    await toggleFavorite(document.id);
  }

    /// ODF-009: system share sheet for the original file (BRD §13's error
  /// messages apply first via [_verifyStillAccessible]).
  Future<void> shareDocument(DocumentModel document) async {
    if (!await _verifyStillAccessible(document)) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(document.path)], title: document.displayName));
  }

  /// Hands the file to another app to render via Android's `ACTION_VIEW`
  /// chooser, since OpenReader has no reader of its own yet.
  Future<void> openWithExternalApp(DocumentModel document) async {
    if (!await _verifyStillAccessible(document)) return;
    final result = await OpenFilex.open(document.path);
    if (result.type != ResultType.done) {
      CustomSnackbar.error(result.message, title: document.displayName);
    }
  }

  /// Desktop: shows the file in Finder, File Explorer or the file manager, with the file selected where
  /// the platform can do that (macOS, Windows) and its folder opened otherwise (Linux).
  Future<void> revealInFolder(DocumentModel document) async {
    if (!await _verifyStillAccessible(document)) return;
    try {
      final path = document.path;
      final ProcessResult result;
      if (PlatformInfo.isMacOS) {
        result = await Process.run('open', ['-R', path]);
      } else if (PlatformInfo.isWindows) {
        // explorer.exe reports exit code 1 even when it worked, so only a failure to start counts.
        await Process.run('explorer.exe', ['/select,$path']);
        return;
      } else {
        result = await Process.run('xdg-open', [File(path).parent.path]);
      }
      if (result.exitCode != 0) {
        CustomSnackbar.error('Could not open the folder.', title: document.displayName);
      }
    } on ProcessException {
      CustomSnackbar.error('Could not open the folder.', title: document.displayName);
    }
  }

  /// ODF-021/023: shared BRD §13 guard for a document whose file may have
  /// been deleted, or whose storage permission may have been revoked, since
  /// it was indexed. Called before open/share/open-with proceed.
  Future<bool> _verifyStillAccessible(DocumentModel document, {bool skipAccessCheck = false}) async {
    if (!File(document.path).existsSync()) {
      unawaited(_handleMissing(document));
      return false;
    }
    // Only shared storage needs the permission; a copy in the app's own cache or files folders (a
    // file shared or picked into OpenReader) opens in limited mode too.
    if (!skipAccessCheck && !await _privatePaths.contains(document.path) && !await _storageAccess.hasAccess()) {
      _showNoAccess(document);
      return false;
    }
    return true;
  }

  /// A file that is gone: its Recents entry is removed at once, and the user may Locate it (the file
  /// picked gets its favorite and reading position and is opened).
  Future<void> _handleMissing(DocumentModel document) async {
    final located = await _relocation.handleMissing(
      document,
      removeFromRecents: removeFromRecent,
      onChanged: () => readerClosed.value++,
    );
    if (located != null) await openDocument(located);
  }

  void _showNoAccess(DocumentModel document) {
    CustomSnackbar.error(
      'OpenReader no longer has access to this file.',
      title: document.displayName,
      actionLabel: 'Grant Access',
      onAction: () => unawaited(requestStorageAccessFlow(access: _storageAccess, isClosed: () => isClosed)),
    );
  }

  Future<void> removeFromRecent(String documentId) => _recentRepository.remove(documentId);

  /// Asks for confirmation, then permanently deletes the file from device
  /// storage. Returns true if it was deleted, so the calling screen can
  /// reload its list.
  Future<bool> confirmAndDelete(DocumentModel document) async {
    final confirmed = await showConfirmDialog(
      title: 'Delete file?',
      message: '"${document.displayName}" will be permanently deleted from your device. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return false;
    return deleteDocument(document);
  }

  Future<bool> deleteDocument(DocumentModel document) async {
    if (!await _privatePaths.contains(document.path) && !await _storageAccess.hasAccess()) {
      _showNoAccess(document);
      return false;
    }
    final result = await _documentRepository.deleteDocument(document);
    return result.fold(
      (failure) {
        CustomSnackbar.error(failure.message, title: document.displayName);
        return false;
      },
      (_) {
        favoriteIds.remove(document.id);
        CustomSnackbar.info('File deleted.', title: document.displayName);
        return true;
      },
    );
  }
}
