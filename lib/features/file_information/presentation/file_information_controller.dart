import 'package:get/get.dart';

import '../../../core/domain/models/document_model.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../services/utilities/file_metadata_service.dart';

/// Drives the File Information screen (BRD 9.16, ODF-010): fresh filesystem
/// metadata plus the Share/Favorite/Open With actions, all delegated to the
/// single shared [DocumentInteractionController] rather than reimplemented.
class FileInformationController extends BaseController {
  final DocumentModel document;
  final FileMetadataService _metadataService;
  final DocumentInteractionController _interactions;

  FileInformationController({
    required this.document,
    FileMetadataService? metadataService,
    DocumentInteractionController? interactions,
  })  : _metadataService = metadataService ?? FileMetadataService.instance,
        _interactions = interactions ?? Get.find<DocumentInteractionController>();

  final metadata = Rxn<FileMetadata>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    status.value = StateStatus.loading;
    final result = await _metadataService.read(
      path: document.path,
      extension: document.extension,
      category: document.category,
    );
    if (result == null) {
      // BRD 9.16 corner case: file deleted after this screen opened.
      status.value = StateStatus.error;
      errorMessage.value = 'This file may have been moved or deleted.';
      return;
    }
    metadata.value = result;
    status.value = StateStatus.success;
  }

  bool get isFavorite => _interactions.isFavorite(document.id);

  Future<void> toggleFavorite() => _interactions.toggleFavorite(document.id);

  /// Re-checks accessibility itself (a file/permission change between this
  /// screen's [load] and an action button press is the BRD 9.16 corner case
  /// this guards, not just the initial load).
  Future<void> share() => _interactions.shareDocument(document);

  Future<void> openWith() => _interactions.openWithExternalApp(document);
}
