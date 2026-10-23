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
import '../widgets/show_dialog/confirm_dialog.dart';
import '../widgets/snackbar/custom_snackbar.dart';
import '../../../services/utilities/storage_access_service.dart';
import '../../domain/models/document_category.dart';
import '../../../res/routes/app_routes.dart';

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

  DocumentInteractionController({
    FavoriteRepository? favoriteRepository,
    RecentRepository? recentRepository,
    DocumentRepository? documentRepository,
    StorageAccessService? storageAccess,
  })  : _favoriteRepository = favoriteRepository ?? FavoriteRepositoryImpl(),
        _recentRepository = recentRepository ?? RecentRepositoryImpl(),
        _documentRepository = documentRepository ?? DocumentRepositoryImpl(),
        _storageAccess = storageAccess ?? StorageAccessService.instance;

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
        _openReader(AppRoutes.pdfReader, document);
        return;
      case DocumentCategory.word:
        _openReader(AppRoutes.wordReader, document);
        return;
      case DocumentCategory.excel:
        _openReader(AppRoutes.excelReader, document);
        return;
      case DocumentCategory.text:
        _openReader(AppRoutes.textReader, document);
        return;
      case DocumentCategory.csv:
        _openReader(AppRoutes.csvReader, document);
        return;
      case DocumentCategory.powerpoint:
        _openReader(AppRoutes.powerpointReader, document);
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
  void readerClosedAfter(Future<Object?>? save) {
    if (save == null) {
      readerClosed.value++;
    } else {
      unawaited(save.whenComplete(() => readerClosed.value++));
    }
  }

  void _openReader(String route, DocumentModel document) {
    unawaited(Get.toNamed(route, arguments: document));
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

  /// ODF-021/023: shared BRD §13 guard for a document whose file may have
  /// been deleted, or whose storage permission may have been revoked, since
  /// it was indexed. Called before open/share/open-with proceed.
  Future<bool> _verifyStillAccessible(DocumentModel document, {bool skipAccessCheck = false}) async {
    if (!File(document.path).existsSync()) {
      CustomSnackbar.error(
        'This file may have been moved or deleted.',
        title: document.displayName,
        actionLabel: 'Remove from Recents',
        onAction: () => removeFromRecent(document.id),
      );
      return false;
    }
    if (!skipAccessCheck && !await _storageAccess.hasAccess()) {
      CustomSnackbar.error(
        'OpenReader no longer has access to this file.',
        title: document.displayName,
        actionLabel: 'Grant Access',
        onAction: () => _storageAccess.requestOrOpenSettings(),
      );
      return false;
    }
    return true;
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
    if (!await _storageAccess.hasAccess()) {
      CustomSnackbar.error(
        'OpenReader no longer has access to this file.',
        title: document.displayName,
        actionLabel: 'Grant Access',
        onAction: () => _storageAccess.requestOrOpenSettings(),
      );
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
