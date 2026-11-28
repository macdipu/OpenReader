import 'package:get/get.dart';

import '../../../domain/models/document_model.dart';
import '../../controllers/document_interaction_controller.dart';
import '../../utils/platform_info.dart';

/// "Show in Finder" and its siblings, shared by every reader's "More actions" menu. Desktop only: a
/// phone has no folder view to show a file in.
bool get showInFolderAvailable => PlatformInfo.isDesktop;

/// The menu text for "show this file in its folder", worded for the platform's file manager.
String get showInFolderLabel => PlatformInfo.isMacOS
    ? 'Show in Finder'
    : PlatformInfo.isWindows
        ? 'Show in Explorer'
        : 'Show in folder';

Future<void> showDocumentInFolder(DocumentModel document) =>
    Get.find<DocumentInteractionController>().revealInFolder(document);
