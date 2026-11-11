import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../helpers/temp_dir.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openreader/core/domain/models/document_category.dart';
import 'package:openreader/core/domain/models/document_model.dart';
import 'package:openreader/features/workspace/presentation/workspace_controller.dart';

DocumentModel _doc(String name, {DocumentCategory category = DocumentCategory.pdf}) => DocumentModel(
      id: name,
      path: '/docs/$name',
      displayName: name,
      extension: name.split('.').last,
      category: category,
      sizeBytes: 1,
      modifiedAt: DateTime(2026),
      lastSeenAt: DateTime(2026),
    );

void main() {
  late WorkspaceController ws;
  late List<String> opened;
  late List<String> closed;

  setUp(() {
    ws = WorkspaceController();
    opened = [];
    closed = [];
    ws.onTabOpened = (tab) => opened.add(tab.document.displayName);
    ws.onTabClosed = (tab) => closed.add(tab.document.displayName);
  });

  String? nameOf(String? id) => ws.tabById(id)?.document.displayName;

  test('opening a document makes a tab, shows it and makes the workspace visible', () {
    expect(ws.open(_doc('a.pdf')), isTrue);
    expect(ws.tabs.length, 1);
    expect(nameOf(ws.activeId), 'a.pdf');
    expect(ws.visible.value, isTrue);
    expect(opened, ['a.pdf']);
  });

  test('opening a document that is already open focuses its tab instead of adding one', () {
    ws.open(_doc('a.pdf'));
    ws.open(_doc('b.pdf'));
    ws.open(_doc('a.pdf'));
    expect(ws.tabs.length, 2);
    expect(opened, ['a.pdf', 'b.pdf']);
    expect(nameOf(ws.activeId), 'a.pdf');
  });

  test('the tab limit refuses another document', () {
    for (var i = 0; i < WorkspaceController.maxTabs; i++) {
      expect(ws.open(_doc('d$i.pdf')), isTrue);
    }
    expect(ws.open(_doc('one-too-many.pdf')), isFalse);
    expect(ws.tabs.length, WorkspaceController.maxTabs);
  });

  group('closing', () {
    test('the next tab takes over, or the previous one at the end', () {
      ws
        ..open(_doc('a.pdf'))
        ..open(_doc('b.pdf'))
        ..open(_doc('c.pdf'));
      ws.show(ws.tabs[1].id);
      ws.close(ws.tabs[1].id);
      expect(nameOf(ws.activeId), 'c.pdf');
      ws.close(ws.activeId!);
      expect(nameOf(ws.activeId), 'a.pdf');
      expect(closed, ['b.pdf', 'c.pdf']);
    });

    test('closing the last tab hides the workspace', () {
      ws.open(_doc('a.pdf'));
      ws.close(ws.activeId!);
      expect(ws.tabs, isEmpty);
      expect(ws.visible.value, isFalse);
      expect(ws.activeId, isNull);
    });

    test('close others keeps one', () {
      ws
        ..open(_doc('a.pdf'))
        ..open(_doc('b.pdf'))
        ..open(_doc('c.pdf'));
      ws.closeOthers(ws.tabs[1].id);
      expect(ws.tabs.map((t) => t.document.displayName), ['b.pdf']);
    });
  });

  group('side by side', () {
    test('splitting puts another tab in the right pane and focuses it', () {
      ws
        ..open(_doc('a.pdf'))
        ..open(_doc('b.pdf'));
      ws.show(ws.tabs[0].id);
      ws.toggleSplit();
      expect(ws.split.value, isTrue);
      expect(nameOf(ws.paneTabs[0]), 'a.pdf');
      expect(nameOf(ws.paneTabs[1]), 'b.pdf');
      expect(ws.focusedPane.value, 1);
    });

    test('splitting at the tab limit with nothing else to show leaves the right pane empty', () {
      for (var i = 0; i < WorkspaceController.maxTabs; i++) {
        ws.open(_doc('d$i.pdf'));
      }
      ws.show(ws.tabs[0].id);
      while (ws.tabs.length > 1) {
        ws.close(ws.tabs.last.id);
      }
      for (var i = 0; i < WorkspaceController.maxTabs - 1; i++) {
        ws.duplicate(ws.tabs[0].id);
      }
      expect(ws.isFull, isTrue);
      ws.closeOthers(ws.tabs[0].id);
      // One tab, room for a copy: the right pane gets one.
      ws.toggleSplit();
      expect(ws.split.value, isTrue);
      expect(ws.paneTabs[1], isNotNull);
    });

    test('a document opened while the right pane is focused lands in it', () {
      ws.open(_doc('a.pdf'));
      ws.toggleSplit();
      ws.open(_doc('b.pdf'));
      expect(nameOf(ws.paneTabs[0]), 'a.pdf');
      expect(nameOf(ws.paneTabs[1]), 'b.pdf');
    });

    test('choosing a tab that is in the other pane focuses that pane rather than duplicating it', () {
      ws
        ..open(_doc('a.pdf'))
        ..open(_doc('b.pdf'));
      ws.show(ws.tabs[0].id);
      ws.toggleSplit();
      ws.show(ws.tabs[0].id);
      expect(ws.focusedPane.value, 0);
      expect(ws.paneTabs.where((id) => id == ws.tabs[0].id).length, 1);
    });

    test('showing a tab in the other pane swaps the two', () {
      ws
        ..open(_doc('a.pdf'))
        ..open(_doc('b.pdf'));
      ws.show(ws.tabs[0].id);
      ws.toggleSplit();
      ws.showInPane(ws.tabs[0].id, 1);
      expect(nameOf(ws.paneTabs[1]), 'a.pdf');
      expect(nameOf(ws.paneTabs[0]), 'b.pdf');
    });

    test('closing the tab in the right pane closes the split when nothing else is left to show', () {
      ws
        ..open(_doc('a.pdf'))
        ..open(_doc('b.pdf'));
      ws.show(ws.tabs[0].id);
      ws.toggleSplit();
      ws.close(ws.paneTabs[1]!);
      expect(ws.split.value, isFalse);
      expect(nameOf(ws.paneTabs[0]), 'a.pdf');
    });

    test('closing the left tab while split moves the right one over', () {
      ws
        ..open(_doc('a.pdf'))
        ..open(_doc('b.pdf'));
      ws.show(ws.tabs[0].id);
      ws.toggleSplit();
      ws.close(ws.paneTabs[0]!);
      expect(ws.split.value, isFalse);
      expect(nameOf(ws.paneTabs[0]), 'b.pdf');
    });

    test('the divider ratio stays within bounds', () {
      ws.setRatio(0.05);
      expect(ws.ratio.value, WorkspaceController.minRatio);
      ws.setRatio(0.99);
      expect(ws.ratio.value, WorkspaceController.maxRatio);
    });
  });

  group('same document twice, as an editor does', () {
    test('splitting with a single document opens a second, independent view of it', () {
      ws.open(_doc('a.pdf'));
      ws.toggleSplit();
      expect(ws.tabs.length, 2);
      expect(ws.tabs[1].document.id, ws.tabs[0].document.id);
      expect(ws.tabs[1].title, 'a.pdf (2)');
      expect(ws.paneTabs[0], ws.tabs[0].id);
      expect(ws.paneTabs[1], ws.tabs[1].id);
      expect(opened, ['a.pdf', 'a.pdf'], reason: 'each view gets its own reader');
    });

    test('"split right" on a tab opens a copy in the right pane', () {
      ws
        ..open(_doc('a.pdf'))
        ..open(_doc('b.pdf'));
      expect(ws.duplicateToRight(ws.tabs[0].id), isTrue);
      expect(ws.split.value, isTrue);
      expect(nameOf(ws.paneTabs[1]), 'a.pdf');
      expect(ws.tabs.map((t) => t.title), ['a.pdf', 'a.pdf (2)', 'b.pdf']);
    });

    test('opening the document again focuses the original rather than adding a third view', () {
      ws.open(_doc('a.pdf'));
      ws.duplicateToRight(ws.tabs[0].id);
      ws.open(_doc('a.pdf'));
      expect(ws.tabs.length, 2);
    });

    test('copies are numbered one after another', () {
      ws.open(_doc('a.pdf'));
      ws.duplicate(ws.tabs[0].id);
      ws.duplicate(ws.tabs[0].id);
      expect(ws.tabs.map((t) => t.copy).toSet(), {1, 2, 3});
    });

    test('closing the side of a copy closes the copy; closing a side with a real tab keeps it', () {
      ws.open(_doc('a.pdf'));
      ws.toggleSplit(); // right pane holds copy "a.pdf (2)"
      ws.closePane(1);
      expect(ws.split.value, isFalse);
      expect(ws.tabs.length, 1);
      expect(closed, ['a.pdf']);

      ws.open(_doc('b.pdf'));
      ws.show(ws.tabs[0].id);
      ws.toggleSplit(); // right pane holds b.pdf, a real tab
      ws.closePane(1);
      expect(ws.split.value, isFalse);
      expect(ws.tabs.length, 2);
    });

    test('closing the left side moves the right document over', () {
      ws
        ..open(_doc('a.pdf'))
        ..open(_doc('b.pdf'));
      ws.show(ws.tabs[0].id);
      ws.toggleSplit();
      ws.closePane(0);
      expect(ws.split.value, isFalse);
      expect(nameOf(ws.paneTabs[0]), 'b.pdf');
    });

    test('the tab limit stops a copy too', () {
      for (var i = 0; i < WorkspaceController.maxTabs; i++) {
        ws.open(_doc('d$i.pdf'));
      }
      expect(ws.duplicateToRight(ws.tabs[0].id), isFalse);
      expect(ws.tabs.length, WorkspaceController.maxTabs);
    });
  });

  group('remembering the open tabs', () {
    late Directory dir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dir = await Directory.systemTemp.createTemp('workspace_test');
    });

    tearDown(() async => deleteTempDir(dir));

    DocumentModel fileDoc(String name) {
      final file = File('${dir.path}/$name')..writeAsStringSync('x');
      return DocumentModel(
        id: name,
        path: file.path,
        displayName: name,
        extension: 'txt',
        category: DocumentCategory.text,
        sizeBytes: 1,
        modifiedAt: DateTime(2026),
        lastSeenAt: DateTime(2026),
      );
    }

    test('a new session gets the tabs back, with the one that was showing', () async {
      final first = WorkspaceController()..onInit();
      first
        ..open(fileDoc('a.txt'))
        ..open(fileDoc('b.txt'))
        ..open(fileDoc('c.txt'));
      first.show(first.tabs[1].id);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      first.onClose();

      final second = WorkspaceController();
      await second.restore();
      expect(second.tabs.map((t) => t.document.displayName), ['a.txt', 'b.txt', 'c.txt']);
      expect(second.tabs.firstWhere((t) => t.id == second.activeId).document.displayName, 'b.txt');
      expect(second.visible.value, isTrue);
    });

    test('a file that is gone is skipped, and extra views of a document are not remembered', () async {
      final first = WorkspaceController()..onInit();
      first
        ..open(fileDoc('keep.txt'))
        ..open(fileDoc('gone.txt'));
      first.duplicateToRight(first.tabs[0].id);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      first.onClose();
      File('${dir.path}/gone.txt').deleteSync();

      final second = WorkspaceController();
      await second.restore();
      expect(second.tabs.map((t) => t.title), ['keep.txt']);
    });

    test('closing every tab forgets them', () async {
      final first = WorkspaceController()..onInit();
      first.open(fileDoc('a.txt'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      first.close(first.tabs.single.id);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      first.onClose();

      final second = WorkspaceController();
      await second.restore();
      expect(second.tabs, isEmpty);
    });

    test('restoring does not replace what is already open', () async {
      final first = WorkspaceController()..onInit();
      first.open(fileDoc('old.txt'));
      await Future<void>.delayed(const Duration(milliseconds: 600));
      first.onClose();

      final second = WorkspaceController()..open(fileDoc('new.txt'));
      await second.restore();
      expect(second.tabs.map((t) => t.title), ['new.txt']);
    });
  });

  test('reordering moves a tab', () {
    ws
      ..open(_doc('a.pdf'))
      ..open(_doc('b.pdf'))
      ..open(_doc('c.pdf'));
    ws.reorder(0, 3);
    expect(ws.tabs.map((t) => t.document.displayName), ['b.pdf', 'c.pdf', 'a.pdf']);
  });

  test('next and previous cycle through the tabs', () {
    ws
      ..open(_doc('a.pdf'))
      ..open(_doc('b.pdf'))
      ..open(_doc('c.pdf'));
    ws.next();
    expect(nameOf(ws.activeId), 'a.pdf');
    ws.previous();
    expect(nameOf(ws.activeId), 'c.pdf');
  });
}
