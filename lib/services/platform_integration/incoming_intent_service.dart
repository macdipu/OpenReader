import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/presentation/controllers/document_interaction_controller.dart';
import '../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import 'incoming_document_resolver.dart';

/// Wires Android's incoming `ACTION_VIEW`/`ACTION_SEND` intents (BRD §7.7,
/// TASK-009) to [IncomingDocumentResolver] and, on success, the same
/// [DocumentInteractionController.openDocument] seam every other entry point
/// uses (Home, Files, Search, Recents, Favorites).
///
/// Deliberately thin: the actual decision logic lives in [IncomingDocumentResolver],
/// which is unit-tested directly (`test/services/incoming_document_resolver_test.dart`).
/// [handle] and [init] are not covered by any `testWidgets` test in this
/// codebase: a minimal repro (isolated across eleven progressively smaller
/// cases, not assumed from one failure) showed that in this Flutter 3.44.4
/// environment, a `testWidgets` test that both (a) imports anything reaching
/// `document_repository_impl.dart` (i.e. `sqflite`) - which every path to
/// [IncomingDocumentResolver] does - and (b) calls
/// `Directory.systemTemp.createTemp()` anywhere in the same file, hangs
/// `flutter_test`'s own teardown, regardless of whether either import is
/// actually exercised at runtime. Real intent *delivery* from Android is
/// separately unverifiable here anyway (no emulator) - see TASK-009's
/// implementation delta for the full writeup; this is a documented
/// environment gap, not a defect in this class.
class IncomingIntentService {
  final IncomingDocumentResolver _resolver;
  StreamSubscription<List<SharedMediaFile>>? _subscription;

  IncomingIntentService({IncomingDocumentResolver? resolver}) : _resolver = resolver ?? IncomingDocumentResolver();

  Future<void> init() async {
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty) {
      unawaited(handle(initial));
      // Consumes the launch intent so navigating away and back doesn't
      // re-open the same file again.
      await ReceiveSharingIntent.instance.reset();
    }

    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(handle);
  }

  /// The per-intent handling logic (BRD §7.7 steps 3-5). Public (and
  /// `@visibleForTesting`-marked, since [init] is the only real caller) so
  /// tests can exercise it directly without subscribing to `getMediaStream()`
  /// - see this class's own doc comment for why that matters here.
  @visibleForTesting
  Future<void> handle(List<SharedMediaFile> files) async {
    // BRD §7.7 describes a single incoming document; ACTION_SEND_MULTIPLE
    // isn't a document use case OpenReader models, so only the first file is
    // handled - a deliberate scope line, not a silent drop.
    if (files.isEmpty) return;
    final path = files.first.path;

    final resolution = await _resolver.resolve(path);
    switch (resolution.outcome) {
      case IncomingDocumentOutcome.success:
        unawaited(Get.find<DocumentInteractionController>().openDocument(resolution.document!));
      case IncomingDocumentOutcome.unsupported:
        // BRD §13 "Unsupported format".
        CustomSnackbar.error(
          "OpenReader doesn't support this file type.",
          actionLabel: 'Open With',
          onAction: () => OpenFilex.open(path),
        );
      case IncomingDocumentOutcome.inaccessible:
        // BRD §13 "File missing".
        CustomSnackbar.error('This file may have been moved or deleted.');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
