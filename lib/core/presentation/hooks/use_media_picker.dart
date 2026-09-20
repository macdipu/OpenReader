import 'dart:io';

import 'package:openreader/core/presentation/hooks/use_permission.dart';
import 'package:openreader/core/presentation/widgets/snackbar/custom_snackbar.dart';
import 'package:openreader/services/utilities/media_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:permission_handler/permission_handler.dart';

class FilePickOptions {
  final FileType type;
  final List<String>? allowedExtensions;
  final bool allowMultiple;

  const FilePickOptions({
    this.type = FileType.any,
    this.allowedExtensions,
    this.allowMultiple = false,
  });
}

typedef FilePickerResult = (List<File>?, bool, Future<void> Function());

FilePickerResult useFilePicker({FilePickOptions options = const FilePickOptions()}) {
  final (status, isChecking, requestPermission) = usePermission(Permission.storage);
  final pickedFiles = useState<List<File>?>(null);

  Future<void> pick() async {
    if (!status.isGranted) {
      await requestPermission();
    }

    final current = await Permission.storage.status;
    if (!current.isGranted) {
      CustomSnackbar.error(
        'Storage access is required to pick files. Please grant permission in Settings.',
      );
      return;
    }

    final result = await MediaService.instance.pickFiles(
      type: options.type,
      allowedExtensions: options.allowedExtensions,
      allowMultiple: options.allowMultiple,
    );
    result.fold(
      (failure) => CustomSnackbar.error(failure.message),
      (files) {
        if (files.isNotEmpty) pickedFiles.value = files;
      },
    );
  }

  return (pickedFiles.value, isChecking, pick);
}
