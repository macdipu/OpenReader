import 'dart:io';

import 'package:openreader/core/domain/usecase/usecase.dart';
import 'package:openreader/core/presentation/utils/task_runner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// A service to handle media selection (images, videos, files).
class MediaService {
  MediaService._();
  static final MediaService instance = MediaService._();

  /// Pick one or more files from the device.
  ResultFuture<List<File>> pickFiles({
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    return runTask(() async {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          // Note: On Android 13+, storage permission might be handled differently (media-specific)
          // but permission_handler usually handles the abstraction.
        }
      }

      final FilePickerResult? result = await FilePicker.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
      );

      if (result == null || result.files.isEmpty) return [];

      return result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();
    });
  }
}
