import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_reader_kit/docx.dart';
import 'package:open_reader_kit/open_reader_kit.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'open_reader_kit example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

/// Enter the path of a file on the device, then open it.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _path = TextEditingController();

  /// Reading positions by path. A real app would persist these (they are
  /// plain JSON-safe maps).
  final _positions = <String, ReadingPosition>{};

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  void _open(Widget Function(String path) page) {
    final path = _path.text.trim();
    if (path.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page(path)));
  }

  @override
  Widget build(BuildContext context) {
    final extensions = DocumentFormat.supportedExtensions.join(', ');
    return Scaffold(
      appBar: AppBar(title: const Text('open_reader_kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _path,
            decoration: InputDecoration(
              labelText: 'File path',
              helperText: 'An absolute path to a file the app can read ($extensions).',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _open(
              (path) => Scaffold(
                appBar: AppBar(title: Text(path.split(Platform.pathSeparator).last)),
                body: DocumentViewer.file(
                  path,
                  initialPosition: _positions[path],
                  onPositionChanged: (position) => _positions[path] = position,
                ),
              ),
            ),
            child: const Text('Open with DocumentViewer'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _open((path) => WordSearchPage(path: path)),
            child: const Text('Open a .docx with search'),
          ),
        ],
      ),
    );
  }
}

/// A per-format reader: [WordDocumentController] + [WordDocumentView], with
/// search and a layout switch in the app bar.
class WordSearchPage extends StatefulWidget {
  const WordSearchPage({super.key, required this.path});

  final String path;

  @override
  State<WordSearchPage> createState() => _WordSearchPageState();
}

class _WordSearchPageState extends State<WordSearchPage> {
  final _controller = WordDocumentController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _controller.load(await File(widget.path).readAsBytes());
    } on FileSystemException {
      if (mounted) _controller.rejectAsCorrupted();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = _controller.searchController;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: const InputDecoration(hintText: 'Search', border: InputBorder.none),
          onChanged: _controller.search,
        ),
        actions: [
          ListenableBuilder(
            listenable: search,
            builder: (context, _) => Center(
              child: Text(search.matchCount == 0 ? '' : '${search.currentMatchIndex + 1}/${search.matchCount}'),
            ),
          ),
          IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: _controller.previousMatch),
          IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: _controller.nextMatch),
          IconButton(
            icon: const Icon(Icons.view_agenda_outlined),
            tooltip: 'Continuous / print layout',
            onPressed: _controller.toggleViewMode,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        // The view shows a spinner until the document is parsed.
        builder: (context, _) => switch (_controller.error) {
          null => WordDocumentView(controller: _controller),
          final error => Center(child: Text('Could not open the document (${error.name}).')),
        },
      ),
    );
  }
}
