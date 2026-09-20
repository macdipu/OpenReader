import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// BRD §9.10 Scenario C / §13 "Wrong PDF password". Shown once per attempt
/// by [PdfReaderController.providePassword] - [showIncorrectHint] is true
/// on every call after the first, since pdfrx only re-invokes the password
/// provider when the previous attempt failed.
class PdfPasswordDialog extends StatefulWidget {
  final bool showIncorrectHint;

  const PdfPasswordDialog({super.key, required this.showIncorrectHint});

  @override
  State<PdfPasswordDialog> createState() => _PdfPasswordDialogState();
}

class _PdfPasswordDialogState extends State<PdfPasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(Icons.key_rounded, color: Theme.of(context).colorScheme.secondary),
      title: const Text('Password required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showIncorrectHint)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Incorrect password.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter password'),
            onSubmitted: (value) => Get.back(result: value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        FilledButton(onPressed: () => Get.back(result: _controller.text), child: const Text('Unlock')),
      ],
    );
  }
}
