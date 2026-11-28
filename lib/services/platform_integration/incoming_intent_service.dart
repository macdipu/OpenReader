import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../core/presentation/controllers/document_interaction_controller.dart';
import '../../core/presentation/utils/logger.dart';
import '../../core/presentation/utils/platform_info.dart';
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
  StreamSubscription<dynamic>? _subscription;

  /// Android delivers `{path, mimeType, displayName}` maps from `MainActivity`;
  /// see that class for why intent intake is native on Android.
  static const EventChannel _incomingDocuments = EventChannel('openreader/incoming_intent/events');

  IncomingIntentService({IncomingDocumentResolver? resolver}) : _resolver = resolver ?? IncomingDocumentResolver();

  /// Opens a file by path - used for desktop command-line arguments and the
  /// "Open file" picker, which have no [SharedMediaFile] wrapper.
  Future<void> handlePath(String path) => handle([SharedMediaFile(path: path, type: SharedMediaType.file)]);

  Future<void> init() async {
    // Android: the activity resolves the intent itself (ContentResolver MIME
    // lookup + cache copy), so shares from apps that omit the MIME type - the
    // case the plugin cannot classify - still open. The plugin is iOS-only.
    if (PlatformInfo.isAndroid) {
      _subscription = _incomingDocuments.receiveBroadcastStream().listen(
        _handleNativeDocument,
        onError: (Object error) => AppLogger.warning('[INTENT] native document error: $error'),
      );
      return;
    }

    // receive_sharing_intent only exists on Android/iOS; calling it on
    // Windows/macOS/Linux throws MissingPluginException.
    if (!PlatformInfo.isMobile) return;
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    AppLogger.info('[INTENT] init: initialMedia=${initial.length} ${_describe(initial)}');
    if (initial.isNotEmpty) {
      unawaited(handle(initial));
      // Consumes the launch intent so navigating away and back doesn't
      // re-open the same file again.
      await ReceiveSharingIntent.instance.reset();
    }

    _subscription = ReceiveSharingIntent.instance.getMediaStream().listen(handle);
  }

  /// Turns a native `{path, mimeType}` payload into the same [handle] call the
  /// rest of the app uses.
  void _handleNativeDocument(dynamic event) {
    if (event is! Map) {
      AppLogger.warning('[INTENT] unexpected native payload: $event');
      return;
    }
    final path = event['path'];
    if (path is! String || path.isEmpty) {
      AppLogger.warning('[INTENT] native payload without a path: $event');
      return;
    }
    final mimeType = event['mimeType'];
    final displayName = event['displayName'];
    AppLogger.info('[INTENT] native document: path=$path mime=$mimeType');
    unawaited(
      handle(
        [SharedMediaFile(path: path, type: SharedMediaType.file, mimeType: mimeType is String ? mimeType : null)],
        displayName: displayName is String ? displayName : null,
      ),
    );
  }

  /// Log-safe summary of what the sharing plugin handed over. Kept as a single
  /// line so `adb logcat -s OpenReaderIntent` and the Flutter console both stay
  /// readable.
  static String _describe(List<SharedMediaFile> files) => files
      .map((f) => '{path: ${f.path}, type: ${f.type.name}, mime: ${f.mimeType}}')
      .join(', ');

  /// The per-intent handling logic (BRD §7.7 steps 3-5). Public (and
  /// `@visibleForTesting`-marked, since [init] is the only real caller) so
  /// tests can exercise it directly without subscribing to `getMediaStream()`
  /// - see this class's own doc comment for why that matters here.
  @visibleForTesting
  Future<void> handle(List<SharedMediaFile> files, {String? displayName}) async {
    // BRD §7.7 describes a single incoming document; ACTION_SEND_MULTIPLE
    // isn't a document use case OpenReader models, so only the first file is
    // handled - a deliberate scope line, not a silent drop.
    if (files.isEmpty) return;
    final incoming = files.first;
    AppLogger.info(
      '[INTENT] handle: path=${incoming.path} mime=${incoming.mimeType} sourceType=${incoming.type.name}',
    );

    final path = incoming.path;
    final mimeType = incoming.mimeType;

    final resolution = await _resolver.resolve(path, mimeType: mimeType, displayName: displayName);
    AppLogger.info('[INTENT] resolve outcome=${resolution.outcome.name} document=${resolution.document?.path}');
    switch (resolution.outcome) {
      case IncomingDocumentOutcome.success:
        // On a cold start this runs while the shell route is still building;
        // pushing the reader then leaves a blank gray screen. Wait for the
        // first frame so the shell is mounted underneath.
        await _afterFirstFrame();
        unawaited(Get.find<DocumentInteractionController>().openDocument(resolution.document!, fromOtherApp: true));
      case IncomingDocumentOutcome.unsupported:
        AppLogger.warning(
          '[INTENT] unsupported: no reader for "$path" '
          '(extension has no category and mime "$mimeType" matched no known format)',
        );
        // BRD §13 "Unsupported format".
        CustomSnackbar.error(
          "OpenReader doesn't support this file type.",
          actionLabel: 'Open With',
          onAction: () => OpenFilex.open(path),
        );
      case IncomingDocumentOutcome.inaccessible:
        AppLogger.warning('[INTENT] inaccessible: "$path" is missing or unreadable');
        // BRD §13 "File missing".
        CustomSnackbar.error('This file may have been moved or deleted.');
    }
  }

  /// Time the shell gets to mount after its first frame, so the reader never
  /// opens over a blank screen. Was 300 ms; a frame is enough.
  static const _shellSettle = Duration(milliseconds: 50);

  Future<void> _afterFirstFrame() {
    final binding = WidgetsBinding.instance;
    if (binding.rootElement != null && !binding.renderViews.isEmpty && binding.schedulerPhase == SchedulerPhase.idle) {
      return Future<void>.delayed(_shellSettle);
    }
    final done = Completer<void>();
    binding.addPostFrameCallback((_) => Future<void>.delayed(_shellSettle, done.complete));
    return done.future;
  }

  void dispose() {
    _subscription?.cancel();
  }
}
