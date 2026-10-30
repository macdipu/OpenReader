import 'package:flutter/material.dart';
import '../../../core/presentation/widgets/show_dialog/show_dialog.dart';

import '../../../core/presentation/utils/platform_info.dart';
import '../../../core/presentation/widgets/snackbar/custom_snackbar.dart';
import '../../../services/platform_integration/default_app_service.dart';

/// Offers to make OpenReader the default app, for every supported document
/// or only chosen types (e.g. just PDFs). [firstRun] adds "Don't ask again".
Future<void> showDefaultAppDialog({bool firstRun = false}) async {
  if (firstRun) await DefaultAppService.instance.recordPromptShown();
  await showAppDialog<void>(child: _DefaultAppDialog(firstRun: firstRun), hasBlur: false);
}

/// Shows the first-run prompt once the shell is up (a few launches at most).
Future<void> maybePromptDefaultApp() async {
  if (!DefaultAppService.instance.shouldPrompt()) return;
  await Future<void>.delayed(const Duration(seconds: 1));
  await showDefaultAppDialog(firstRun: true);
}

class _DefaultAppDialog extends StatefulWidget {
  final bool firstRun;
  const _DefaultAppDialog({required this.firstRun});

  @override
  State<_DefaultAppDialog> createState() => _DefaultAppDialogState();
}

class _DefaultAppDialogState extends State<_DefaultAppDialog> {
  final _selected = <DocumentType>{...DocumentType.values};
  bool _onlySome = false;
  bool _busy = false;

  String get _explain {
    if (PlatformInfo.isAndroid) {
      return 'Android asks you per file type: open a document, pick OpenReader and tap Always. '
          'We\'ll open the default-apps settings for you.';
    }
    if (PlatformInfo.isWindows) {
      return 'Windows keeps this choice to itself, so we\'ll open Settings > Default apps with OpenReader '
          'selected. Pick it for the types you want.';
    }
    if (PlatformInfo.isMacOS) return 'macOS may ask you to confirm each type.';
    return 'Sets OpenReader as the default app for the types you choose.';
  }

  String get _action => PlatformInfo.isWindows || PlatformInfo.isAndroid ? 'Open settings' : 'Make default';

  Future<void> _apply() async {
    setState(() => _busy = true);
    final types = _onlySome ? _selected : DocumentType.values.toSet();
    final result = await DefaultAppService.instance.makeDefault(types);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (result.success) {
      CustomSnackbar.success(result.message);
    } else {
      CustomSnackbar.error(result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Make OpenReader your default reader?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_explain, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              RadioGroup<bool>(
                groupValue: _onlySome,
                onChanged: (v) => setState(() => _onlySome = v ?? false),
                child: const Column(
                  children: [
                    RadioListTile<bool>(
                      value: false,
                      contentPadding: EdgeInsets.zero,
                      title: Text('All supported documents'),
                      subtitle: Text('PDF, Word, Excel, PowerPoint, CSV, text, Markdown'),
                    ),
                    RadioListTile<bool>(
                      value: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('Only some types'),
                      subtitle: Text('For example, just PDFs'),
                    ),
                  ],
                ),
              ),
              if (_onlySome)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final type in DocumentType.values)
                        FilterChip(
                          label: Text(type.label),
                          selected: _selected.contains(type),
                          onSelected: (on) => setState(() => on ? _selected.add(type) : _selected.remove(type)),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.firstRun)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await DefaultAppService.instance.dismissPromptForever();
                    if (mounted) Navigator.of(context).pop();
                  },
            child: const Text('Don\'t ask again'),
          ),
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(widget.firstRun ? 'Not now' : 'Cancel')),
        FilledButton(
          onPressed: _busy || (_onlySome && _selected.isEmpty) ? null : _apply,
          child: Text(_action),
        ),
      ],
    );
  }
}
