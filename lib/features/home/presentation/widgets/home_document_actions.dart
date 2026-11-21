import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/domain/models/recent_document_model.dart';
import '../../../../core/presentation/controllers/document_interaction_controller.dart';
import '../../../../core/presentation/utils/platform_info.dart';
import '../../../../core/presentation/widgets/show_dialog/confirm_dialog.dart';
import '../../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../../../services/utilities/reveal_in_folder.dart';
import '../../../file_information/presentation/file_information_view.dart';
import '../home_controller.dart';

/// One thing desktop Home can do with a recent document. The inspector lists these as labeled
/// rows and a right-click shows them as a menu, so both offer the same actions.
class HomeDocumentAction {
  final String label;
  final IconData icon;
  final VoidCallback onInvoke;

  /// Removes the file from the device: drawn in the error colour.
  final bool destructive;

  const HomeDocumentAction(this.label, this.icon, this.onInvoke, {this.destructive = false});
}

/// The labeled actions for [recent]: favorites, share, open with, show in folder (desktop),
/// copy path, file info, remove from history.
List<HomeDocumentAction> homeDocumentActions(
  BuildContext context, {
  required RecentDocumentModel recent,
  required DocumentInteractionController interactions,
  required HomeController controller,
}) {
  final document = recent.document;
  final favorite = interactions.isFavorite(document.id);
  return [
    HomeDocumentAction(
      favorite ? 'Remove from favorites' : 'Add to favorites',
      favorite ? Icons.star_rounded : Icons.star_outline_rounded,
      () => unawaited(interactions.toggleFavorite(document.id)),
    ),
    HomeDocumentAction('Share', Icons.ios_share_rounded, () => unawaited(interactions.shareDocument(document))),
    HomeDocumentAction(
      'Open with another app',
      Icons.open_in_new_rounded,
      () => unawaited(interactions.openWithExternalApp(document)),
    ),
    if (PlatformInfo.isDesktop)
      HomeDocumentAction('Show in folder', Icons.folder_open_outlined, () => unawaited(revealInFolder(document.path))),
    HomeDocumentAction('Copy path', Icons.link_rounded, () => unawaited(copyToClipboard(document.path, 'Path copied'))),
    HomeDocumentAction(
      'File info',
      Icons.info_outline_rounded,
      () => unawaited(showFileInformationSheet(context, document)),
    ),
    HomeDocumentAction(
      'Remove from history',
      Icons.history_toggle_off_rounded,
      () => unawaited(controller.removeFromHistory(document.id)),
    ),
  ];
}

Future<void> copyToClipboard(String text, String done) async {
  await Clipboard.setData(ClipboardData(text: text));
  CustomSnackbar.success(done);
}

/// The Delete key on a table row: asks first, then removes the row from reading history (the
/// file itself stays).
Future<void> confirmRemoveFromHistory(HomeController controller, RecentDocumentModel recent) async {
  final confirmed = await showConfirmDialog(
    title: 'Remove from history?',
    message: '"${recent.document.displayName}" will no longer be listed in Recent files. The file is not deleted.',
    confirmLabel: 'Remove',
  );
  if (confirmed) await controller.removeFromHistory(recent.document.id);
}

/// Right-click on a row or card: Open, Open beside, the labeled actions, and the file deletion
/// the phone rows' menu offers.
Future<void> showHomeDocumentMenu(
  BuildContext context, {
  required Offset position,
  required RecentDocumentModel recent,
  required DocumentInteractionController interactions,
  required HomeController controller,
}) async {
  final document = recent.document;
  final actions = [
    HomeDocumentAction('Open', Icons.menu_book_outlined, () => unawaited(interactions.openDocument(document))),
    HomeDocumentAction(
      'Open beside',
      Icons.vertical_split_outlined,
      () => unawaited(interactions.openBeside(document)),
    ),
    ...homeDocumentActions(context, recent: recent, interactions: interactions, controller: controller),
    HomeDocumentAction('Delete file', Icons.delete_outline_rounded, () async {
      if (await interactions.confirmAndDelete(document)) await controller.load();
    }, destructive: true),
  ];
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final error = Theme.of(context).colorScheme.error;
  final chosen = await showMenu<HomeDocumentAction>(
    context: context,
    position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
    items: [
      for (final (index, action) in actions.indexed) ...[
        // Opening, then the everyday actions, then the one that deletes.
        if (index == 2 || action.destructive) const PopupMenuDivider(),
        PopupMenuItem(
          value: action,
          height: 40,
          child: Row(
            children: [
              Icon(action.icon, size: 18, color: action.destructive ? error : null),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: action.destructive ? TextStyle(color: error) : null,
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
  chosen?.onInvoke();
}
