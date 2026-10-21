import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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
  /// PowerPoint has no reader yet, so that category still shows the stub
  /// message and records the open itself; every other reader owns its own
  /// `markOpened` calls (initial restore + debounced persistence), so this
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
        unawaited(Get.toNamed(AppRoutes.pdfReader, arguments: document));
        return;
      case DocumentCategory.word:
        unawaited(Get.toNamed(AppRoutes.wordReader, arguments: document));
        return;
      case DocumentCategory.excel:
        unawaited(Get.toNamed(AppRoutes.excelReader, arguments: document));
        return;
      case DocumentCategory.text:
        unawaited(Get.toNamed(AppRoutes.textReader, arguments: document));
        return;
      case DocumentCategory.csv:
        unawaited(Get.toNamed(AppRoutes.csvReader, arguments: document));
        return;
      default:
        break;
    }
    await _recentRepository.markOpened(document.id);
    CustomSnackbar.info(
      '${document.category.label} reader is not part of this build yet.',
      title: document.displayName,
    );
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
        onAction: () => _storageAccess.requestAccess(),
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
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete file?'),
        content: Text('"${document.displayName}" will be permanently deleted from your device. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return false;
    return deleteDocument(document);
  }

  Future<bool> deleteDocument(DocumentModel document) async {
    if (!await _storageAccess.hasAccess()) {
      CustomSnackbar.error(
        'OpenReader no longer has access to this file.',
        title: document.displayName,
        actionLabel: 'Grant Access',
        onAction: () => _storageAccess.requestAccess(),
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
