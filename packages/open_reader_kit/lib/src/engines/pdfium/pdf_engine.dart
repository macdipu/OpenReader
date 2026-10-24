import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'pdf_types.dart';
import 'pdfium_worker.dart';

/// The connection to the PDFium worker isolate, started on first use and
/// shared by every open document.
class _Worker {
  _Worker._();

  static _Worker? _instance;
  static _Worker get instance => _instance ??= _Worker._();

  Future<SendPort>? _port;
  final _replies = ReceivePort();
  final _pending = <int, Completer<Object?>>{};
  var _nextId = 1;

  Future<SendPort> _start() => _port ??= () async {
        final ready = Completer<SendPort>();
        _replies.listen((message) {
          if (message is SendPort) {
            ready.complete(message);
            return;
          }
          final reply = message as List<Object?>;
          final completer = _pending.remove(reply[0]! as int);
          if (completer == null) return;
          if (reply.length > 2) {
            completer.completeError(_error(reply[2]! as String, reply[3]! as String));
          } else {
            completer.complete(reply[1]);
          }
        });
        final isolate = await Isolate.spawn(pdfiumWorkerMain, _replies.sendPort, debugName: 'pdfium');
        isolate.addErrorListener(RawReceivePort((Object? error) {
          for (final completer in _pending.values) {
            completer.completeError(PdfEngineException('PDF engine stopped: $error'));
          }
          _pending.clear();
        }).sendPort);
        return ready.future;
      }();

  static Exception _error(String code, String message) => switch (code) {
        'open' => PdfOpenException(switch (int.tryParse(message)) {
            2 => PdfOpenError.file,
            3 => PdfOpenError.format,
            4 => PdfOpenError.password,
            5 => PdfOpenError.security,
            _ => PdfOpenError.unknown,
          }),
        _ => PdfEngineException('$code: $message'),
      };

  /// Sends a request; [onId] receives its id (for [cancel]).
  Future<Object?> call(String op, List<Object?> args, {PdfPriority priority = PdfPriority.visible, void Function(int)? onId}) async {
    final port = await _start();
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    port.send([id, op, priority.index, ...args]);
    onId?.call(id);
    return completer.future;
  }

  /// Drops a request that hasn't started; its future fails with
  /// [PdfCancelledException]. (One already running still finishes; its
  /// result is discarded.)
  Future<void> cancel(int id) async {
    final completer = _pending.remove(id);
    if (completer == null) return;
    completer.completeError(const PdfCancelledException());
    (await _start()).send([0, PdfiumOp.cancel, 0, id]);
  }
}

/// A rendered region of a page, as RGBA pixels.
class PdfRenderedImage {
  const PdfRenderedImage(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;

  /// Decodes into a [ui.Image] for painting.
  Future<ui.Image> toImage() async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(buffer, width: width, height: height, pixelFormat: ui.PixelFormat.rgba8888);
    try {
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }
}

/// A cancellable render request. [cancel] drops it if it hasn't started,
/// and [result] then fails with [PdfCancelledException].
class PdfRenderTask {
  PdfRenderTask._(this.result);

  final Future<PdfRenderedImage> result;
  int? _id;
  bool _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    if (_id != null) _Worker.instance.cancel(_id!);
  }

  /// The worker's id for the request; a cancel that came first is sent now.
  void _assign(int id) {
    _id = id;
    if (_cancelled) _Worker.instance.cancel(id);
  }
}

/// An open PDF. All PDFium work happens in one shared background isolate;
/// this object holds the document's id there and its page sizes.
class PdfiumDocument {
  PdfiumDocument._(this._id, this.pageSizes);

  final int _id;

  /// Each page's displayed size in points (rotation applied).
  final List<ui.Size> pageSizes;

  int get pageCount => pageSizes.length;

  bool _closed = false;
  bool get isClosed => _closed;

  /// Opens a PDF file. Throws [PdfOpenException] with
  /// [PdfOpenError.password] when it needs a (different) [password].
  static Future<PdfiumDocument> openFile(String path, {String? password}) =>
      _open(path, password);

  /// Opens a PDF held in memory.
  static Future<PdfiumDocument> openBytes(Uint8List bytes, {String? password}) =>
      _open(TransferableTypedData.fromList([bytes]), password);

  static Future<PdfiumDocument> _open(Object source, String? password) async {
    final reply = await _Worker.instance.call(PdfiumOp.open, [source, password]) as List<Object?>;
    final sizes = reply[1]! as Float64List;
    return PdfiumDocument._(reply[0]! as int, [
      for (var i = 0; i + 1 < sizes.length; i += 2) ui.Size(sizes[i], sizes[i + 1]),
    ]);
  }

  /// Renders page [page] (0-based) drawn at [fullWidth] x [fullHeight]
  /// pixels, returning the region [region] of it (all of it by default).
  PdfRenderTask render(
    int page, {
    required int fullWidth,
    required int fullHeight,
    ui.Rect? region,
    PdfPriority priority = PdfPriority.visible,
  }) {
    final area = region ?? ui.Rect.fromLTWH(0, 0, fullWidth.toDouble(), fullHeight.toDouble());
    final x = area.left.floor();
    final y = area.top.floor();
    final width = area.right.ceil() - x;
    final height = area.bottom.ceil() - y;
    late final PdfRenderTask task;
    task = PdfRenderTask._(() async {
      _checkOpen();
      final bytes = await _Worker.instance.call(
        PdfiumOp.render,
        [_id, page, fullWidth, fullHeight, x, y, width, height],
        priority: priority,
        onId: (id) => task._assign(id),
      ) as TransferableTypedData;
      return PdfRenderedImage(bytes.materialize().asUint8List(), width, height);
    }());
    return task;
  }

  /// A whole page scaled down to [width] pixels wide.
  Future<PdfRenderedImage> renderThumbnail(int page, {required int width, PdfPriority priority = PdfPriority.background}) {
    final size = pageSizes[page];
    final height = (width * size.height / size.width).round().clamp(1, 1 << 14);
    return render(page, fullWidth: width, fullHeight: height, priority: priority).result;
  }

  /// The page's text with each character's box.
  Future<PdfPageText> text(int page, {PdfPriority priority = PdfPriority.prefetch}) async {
    _checkOpen();
    final reply = await _Worker.instance.call(PdfiumOp.text, [_id, page], priority: priority) as List<Object?>;
    final text = reply[0]! as String;
    final boxes = reply[1]! as Float32List;
    return PdfPageText(text, [
      for (var i = 0; i + 3 < boxes.length; i += 4) ui.Rect.fromLTRB(boxes[i], boxes[i + 1], boxes[i + 2], boxes[i + 3]),
    ]);
  }

  /// Matches of [query] on one page (case-insensitive; a phrase may wrap
  /// lines), and whether the page has any text at all.
  Future<(bool hasText, List<PdfTextMatch>)> search(int page, String query, {PdfPriority priority = PdfPriority.prefetch}) async {
    _checkOpen();
    final reply = await _Worker.instance.call(PdfiumOp.search, [_id, page, query], priority: priority) as List<Object?>;
    final matches = <PdfTextMatch>[];
    for (final entry in reply[1]! as List<Object?>) {
      final match = entry! as List<Object?>;
      final rects = match[2]! as Float32List;
      matches.add(PdfTextMatch(
        page: page,
        start: match[0]! as int,
        end: match[1]! as int,
        rects: [
          for (var i = 0; i + 3 < rects.length; i += 4) ui.Rect.fromLTRB(rects[i], rects[i + 1], rects[i + 2], rects[i + 3]),
        ],
      ));
    }
    return (reply[0]! as bool, matches);
  }

  /// Links on a page: annotations and web addresses written as text.
  Future<List<PdfLink>> links(int page, {PdfPriority priority = PdfPriority.prefetch}) async {
    _checkOpen();
    final reply = await _Worker.instance.call(PdfiumOp.links, [_id, page], priority: priority) as List<Object?>;
    return [
      for (final entry in reply)
        () {
          final link = entry! as List<Object?>;
          final rects = link[2]! as Float32List;
          final target = link[1]! as int;
          return PdfLink(
            url: link[0] as String?,
            page: target >= 0 ? target : null,
            rects: [
              for (var i = 0; i + 3 < rects.length; i += 4)
                ui.Rect.fromLTRB(rects[i], rects[i + 1], rects[i + 2], rects[i + 3]),
            ],
          );
        }(),
    ];
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _Worker.instance.call(PdfiumOp.close, [_id], priority: PdfPriority.background);
  }

  void _checkOpen() {
    if (_closed) throw const PdfEngineException('Document is closed');
  }
}
