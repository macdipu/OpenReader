import 'package:flutter/services.dart';

import '../../core/presentation/utils/logger.dart';
import '../../core/presentation/utils/platform_info.dart';

/// "Save a copy" of a file to a place the user picks (Android: the system save dialog, streamed in
/// `MainActivity` so a large file is never held in memory). CR-FILE-RELOCATE.
class SaveCopyService {
  SaveCopyService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('openreader/files');

  final MethodChannel _channel;

  /// The MIME type for the save dialog; unknown extensions get the generic one.
  static String mimeTypeFor(String extension) => switch (extension.toLowerCase()) {
    'pdf' => 'application/pdf',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'csv' => 'text/csv',
    'md' => 'text/markdown',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };

  /// Asks where to save [path] as [name] and writes it there. False when the user cancelled, the
  /// copy failed, or the platform has no such dialog.
  Future<bool> save({required String path, required String name, String? mimeType}) async {
    if (!PlatformInfo.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('saveCopy', {'path': path, 'name': name, 'mimeType': mimeType}) ??
          false;
    } on PlatformException catch (e) {
      AppLogger.warning('[SAVE] save copy failed: ${e.code} ${e.message}');
      return false;
    }
  }
}
