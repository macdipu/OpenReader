import 'package:flutter/material.dart';
import 'package:open_reader_kit/open_reader_kit.dart';

import '../library.dart';

/// Any document in the ready-made [DocumentViewer], reopening where it was
/// left and saving where it is now. A password-protected PDF asks for its
/// password.
class ReaderPage extends StatelessWidget {
  const ReaderPage({super.key, required this.library, required this.path});

  final DocumentLibrary library;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName(path))),
      body: DocumentViewer.file(
        path,
        initialPosition: library.positionOf(path),
        onPositionChanged: (position) => library.savePosition(path, position),
        passwordProvider: () => _askPassword(context),
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              switch (error) {
                DocumentLoadError.tooLarge => 'This file is too large to open.',
                DocumentLoadError.corrupted => 'This file is damaged or not what its name says.',
                DocumentLoadError.passwordRequired => 'This PDF needs a password.',
                DocumentLoadError.unsupported => 'open_reader_kit doesn\'t read this kind of file.',
              },
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  /// The PDF's password, or null to give up; asked again after a wrong one.
  static Future<String?> _askPassword(BuildContext context) {
    final field = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Password'),
        content: TextField(
          controller: field,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'This PDF is protected'),
          onSubmitted: (text) => Navigator.of(dialogContext).pop(text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(field.text), child: const Text('Open')),
        ],
      ),
    ).whenComplete(field.dispose);
  }
}
