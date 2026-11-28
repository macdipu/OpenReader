import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../services/platform_integration/incoming_document_resolver.dart';
import '../../../services/platform_integration/save_copy_service.dart';
import '../../../services/utilities/app_private_paths.dart';
import '../../../services/utilities/shared_copy_store.dart';
import '../../data/repositories/app_settings_repository_impl.dart';
import '../../data/repositories/document_repository_impl.dart';
import '../../domain/models/document_model.dart';
import '../../domain/models/keep_state.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../domain/repositories/document_repository.dart';
import '../../domain/repositories/recent_repository.dart';
import '../../data/repositories/recent_repository_impl.dart';
import '../utils/logger.dart';
import '../widgets/show_dialog/file_choice_dialogs.dart';
import '../widgets/snackbar/custom_snackbar.dart';

/// What happens when a file in Recents is gone (moved or deleted), and when the reader of a copy of
/// another app's file is closed (CR-FILE-RELOCATE). Kept apart from [DocumentInteractionController]
/// so both can be tested with the dialogs and the file picker swapped out.
class FileRelocation {
  FileRelocation({
    DocumentRepository? documents,
    RecentRepository? recents,
    AppSettingsRepository? settings,
    AppPrivatePaths? privatePaths,
    SharedCopyStore? copyStore,
    SaveCopyService? saveCopy,
    IncomingDocumentResolver? resolver,
    Future<String?> Function(DocumentModel document)? pickFile,
    Future<bool> Function(String name, {required bool temporaryCopy})? askMissing,
    Future<SharedCopyDecision> Function(DocumentModel document)? askSharedCopy,
    bool Function(String path)? isSharedCopy,
    void Function(String message)? showError,
    void Function(String message)? showSuccess,
  }) : _documents = documents ?? DocumentRepositoryImpl(),
       _recents = recents ?? RecentRepositoryImpl(),
       _settings = settings ?? AppSettingsRepositoryImpl(),
       _privatePaths = privatePaths ?? AppPrivatePaths.instance,
       _copyStore = copyStore ?? SharedCopyStore(),
       _saveCopy = saveCopy ?? SaveCopyService(),
       _resolver = resolver ?? IncomingDocumentResolver(),
       _pickFile = pickFile ?? _pickWithPicker,
       _askMissing = askMissing ?? ((name, {required temporaryCopy}) => showMissingFileDialog(name: name, temporaryCopy: temporaryCopy)),
       _askSharedCopy = askSharedCopy ?? ((document) => showSharedCopyDialog(document: document)),
       _isSharedCopy = isSharedCopy ?? SharedCopyStore.isSharedCopy,
       _showError = showError ?? CustomSnackbar.error,
       _showSuccess = showSuccess ?? CustomSnackbar.success;

  final DocumentRepository _documents;
  final RecentRepository _recents;
  final AppSettingsRepository _settings;
  final AppPrivatePaths _privatePaths;
  final SharedCopyStore _copyStore;
  final SaveCopyService _saveCopy;
  final IncomingDocumentResolver _resolver;
  final Future<String?> Function(DocumentModel document) _pickFile;
  final Future<bool> Function(String name, {required bool temporaryCopy}) _askMissing;
  final Future<SharedCopyDecision> Function(DocumentModel document) _askSharedCopy;
  final bool Function(String path) _isSharedCopy;
  final void Function(String message) _showError;
  final void Function(String message) _showSuccess;

  static Future<String?> _pickWithPicker(DocumentModel document) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: [document.extension.toLowerCase()],
    );
    return result?.files.single.path;
  }

  /// A file that is no longer at its path. Its Recents entry is removed at once, with nothing to
  /// confirm; the user is told, and a file that can be found again may be located (the favorite and
  /// the reading position move to it). Returns the document to open, or null when there is none.
  /// [removeFromRecents] and [onChanged] are the controller's own actions.
  Future<DocumentModel?> handleMissing(
    DocumentModel document, {
    required Future<void> Function(String documentId) removeFromRecents,
    required void Function() onChanged,
  }) async {
    // A copy in the app's own folders (another app's file, or something from the temp folder) has
    // no known original to look for.
    final temporary = _isSharedCopy(document.path) || await _privatePaths.contains(document.path);
    // Read before the entry goes: a located file gets it back.
    var position = const <String, Object?>{};
    try {
      position = (await _recents.getPosition(document.id)).fold((_) => const <String, Object?>{}, (found) => found);
    } catch (_) {
      // No saved position: the entry is still removed, and a located file just opens at the start.
    }
    try {
      await removeFromRecents(document.id);
      onChanged();
    } catch (e) {
      // The message below still tells the user; the entry is just still there.
      AppLogger.warning('[RELOCATE] could not remove ${document.id} from Recents: $e');
    }

    final wantsLocate = await _askMissing(document.displayName, temporaryCopy: temporary);
    if (temporary || !wantsLocate) return null;
    final located = await locate(document);
    if (located == null) return null;
    if (position.isNotEmpty) await _recents.markOpened(located.id, readingPosition: position);
    onChanged();
    return located;
  }

  /// Asks for the file, moves [document]'s history, favorite and reading position to it, and returns
  /// it. Null when the user cancelled or the file cannot be opened.
  Future<DocumentModel?> locate(DocumentModel document) async {
    final picked = await _pickFile(document);
    if (picked == null) return null;

    // On Android a picked file is a cache copy the OS may clear: keep it in app files like a shared one.
    final adoptedPath = await _copyStore.adopt(File(picked));
    final path = adoptedPath ?? picked;
    final resolution = await _resolver.resolve(path, displayName: p.basename(picked));
    final replacement = resolution.document;
    if (replacement == null) {
      _showError("OpenReader can't open that file.");
      return null;
    }
    final relinked = await _documents.relink(
      document.id,
      replacement,
      keepState: adoptedPath != null ? KeepState.kept : null,
    );
    return relinked.fold((failure) {
      AppLogger.error('[RELOCATE] relink failed: ${failure.message}');
      _showError('Could not relink this file: ${failure.message}');
      return null;
    }, (moved) => moved);
  }

  /// A reader closed: when its document is a copy of another app's file that is still undecided, ask
  /// what to do with it (or apply the setting). [onChanged] tells the lists to reload.
  Future<void> onReaderClosed(String? documentId, {required void Function() onChanged}) async {
    if (documentId == null || !_isSharedCopy(documentId)) return;
    final state = (await _documents.getKeepState(documentId)).fold((_) => null, (state) => state);
    if (state != KeepState.pending) return;
    final document = (await _documents.getById(documentId)).fold((_) => null, (document) => document);
    if (document == null) return;

    final action = await _settings.getSharedCopyAction();
    final SharedCopyChoice choice;
    switch (action) {
      case SharedCopyAction.keep:
        choice = SharedCopyChoice.keep;
      case SharedCopyAction.remove:
        choice = SharedCopyChoice.remove;
      case SharedCopyAction.ask:
        final decision = await _askSharedCopy(document);
        choice = decision.choice;
        if (decision.remember && decision.choice != SharedCopyChoice.saveCopy) {
          await _settings.setSharedCopyAction(
            decision.choice == SharedCopyChoice.remove ? SharedCopyAction.remove : SharedCopyAction.keep,
          );
        }
    }

    switch (choice) {
      case SharedCopyChoice.keep:
        await _documents.setKeepState(document.id, KeepState.kept);
      case SharedCopyChoice.saveCopy:
        final saved = await _saveCopy.save(
          path: document.path,
          name: document.displayName,
          mimeType: SaveCopyService.mimeTypeFor(document.extension),
        );
        // The copy in OpenReader stays either way: cancelling the dialog counts as Keep.
        await _documents.setKeepState(document.id, saved ? KeepState.saved : KeepState.kept);
        if (saved) _showSuccess('Saved a copy of ${document.displayName}.');
      case SharedCopyChoice.remove:
        // The file and its row go; Recents and any favorite cascade with the row.
        await _documents.deleteDocument(document);
        onChanged();
    }
  }
}
