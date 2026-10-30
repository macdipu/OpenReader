import 'package:get/get.dart';

import '../../../core/domain/models/document_model.dart';

/// One open document in the workspace.
class WorkspaceTab {
  final String id;
  final DocumentModel document;

  /// 1 for the tab a document opened in; 2, 3 ... for extra views of the same
  /// document (an editor's "split right"), each with its own scroll and zoom.
  final int copy;

  const WorkspaceTab({required this.id, required this.document, this.copy = 1});

  String get title => copy > 1 ? '${document.displayName} ($copy)' : document.displayName;
}

/// Several documents open at once: tabs, and a second pane beside the first.
///
/// This is only the bookkeeping (which tabs exist, which pane shows which,
/// the split and its ratio). The readers themselves are created per tab by
/// `workspace_readers.dart` and drawn by `WorkspaceView`. Phones and narrow
/// windows never enable it and keep opening each document as its own route.
class WorkspaceController extends GetxController {
  /// Most tabs open at once; each keeps a reader (and for a PDF its engine) alive.
  static const maxTabs = 12;

  /// A window narrower than this cannot show two panes.
  static const minSplitWidth = 900.0;

  static const minRatio = 0.25;
  static const maxRatio = 0.75;

  /// Registers and removes the reader behind a tab; set by `workspace_readers.dart`.
  void Function(WorkspaceTab tab)? onTabOpened;
  void Function(WorkspaceTab tab)? onTabClosed;

  final tabs = <WorkspaceTab>[].obs;

  /// The tab id each pane shows; pane 1 is empty unless [split].
  final paneTabs = <String?>[null, null].obs;
  final focusedPane = 0.obs;
  final split = false.obs;

  /// The left pane's share of the width while split.
  final ratio = 0.5.obs;

  /// Whether the workspace, rather than Home / Browse / Library, fills the content area.
  final visible = false.obs;

  /// Set by the shell from the window size. When false, documents open as routes.
  bool enabled = false;

  int _nextId = 0;

  String? get activeId => paneTabs[focusedPane.value];

  WorkspaceTab? tabById(String? id) => id == null ? null : tabs.firstWhereOrNull((t) => t.id == id);

  WorkspaceTab? get activeTab => tabById(activeId);

  bool get isFull => tabs.length >= maxTabs;

  /// Opens [document] in a tab (or focuses its tab if it is already open).
  /// Returns false when the tab limit stops it.
  bool open(DocumentModel document) {
    final existing = tabs.firstWhereOrNull((t) => t.document.id == document.id);
    if (existing != null) {
      show(existing.id);
      return true;
    }
    if (isFull) return false;
    final tab = WorkspaceTab(id: 'tab${_nextId++}', document: document);
    onTabOpened?.call(tab);
    tabs.add(tab);
    show(tab.id);
    return true;
  }

  /// Shows [id] in the focused pane; if the other pane already shows it, focuses that pane instead.
  void show(String id) {
    visible.value = true;
    final inPane = paneTabs.indexOf(id);
    if (inPane >= 0) {
      focusedPane.value = inPane;
      return;
    }
    paneTabs[focusedPane.value] = id;
    paneTabs.refresh();
  }

  void focusPane(int pane) {
    if (pane == 1 && !split.value) return;
    focusedPane.value = pane;
  }

  /// Puts [id] in [pane] (opening the split for the right pane), swapping if it was in the other one.
  void showInPane(String id, int pane) {
    if (pane == 1) split.value = true;
    final other = paneTabs.indexOf(id);
    if (other >= 0 && other != pane) paneTabs[other] = paneTabs[pane];
    paneTabs[pane] = id;
    paneTabs.refresh();
    focusedPane.value = pane;
    visible.value = true;
  }

  void close(String id) {
    final tab = tabById(id);
    if (tab == null) return;
    final index = tabs.indexOf(tab);
    tabs.removeAt(index);
    onTabClosed?.call(tab);

    for (var pane = 0; pane < 2; pane++) {
      if (paneTabs[pane] != id) continue;
      paneTabs[pane] = _neighbour(index, exclude: paneTabs[1 - pane]);
    }
    // The right pane has nothing left to show: back to one pane.
    if (split.value && paneTabs[1] == null) _unsplit();
    // The left pane is empty but the right is not: the right one moves over.
    if (paneTabs[0] == null && paneTabs[1] != null) {
      paneTabs[0] = paneTabs[1];
      _unsplit();
    }
    paneTabs.refresh();
    if (tabs.isEmpty) {
      visible.value = false;
      split.value = false;
      focusedPane.value = 0;
    }
  }

  void closeOthers(String keepId) {
    for (final tab in tabs.toList()) {
      if (tab.id != keepId) close(tab.id);
    }
  }

  /// The tab next to where [index] was, not already shown in the other pane.
  String? _neighbour(int index, {String? exclude}) {
    final candidates = [
      for (var i = index; i < tabs.length; i++) tabs[i].id,
      for (var i = index - 1; i >= 0; i--) tabs[i].id,
    ].where((id) => id != exclude);
    return candidates.isEmpty ? null : candidates.first;
  }

  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final tab = tabs.removeAt(oldIndex);
    tabs.insert(newIndex, tab);
  }

  void toggleSplit() => split.value ? _unsplit() : _openSplit();

  void _openSplit() {
    split.value = true;
    final left = paneTabs[0];
    // The most recently added tab the left pane is not showing, if any; with only one
    // document open, a second view of it (as splitting an editor does).
    var other = tabs.reversed.map((t) => t.id).where((id) => id != left).firstOrNull;
    if (other == null && left != null) other = duplicate(left);
    paneTabs[1] = other;
    paneTabs.refresh();
    focusedPane.value = 1;
  }

  /// Opens another, independent view of the same document in a new tab, right after
  /// [id]'s, so two places in one document (or two zoom levels) can be compared.
  /// Returns the new tab's id, or null at the tab limit.
  String? duplicate(String id) {
    final source = tabById(id);
    if (source == null || isFull) return null;
    final copies = tabs.where((t) => t.document.id == source.document.id).length;
    final tab = WorkspaceTab(id: 'tab${_nextId++}', document: source.document, copy: copies + 1);
    onTabOpened?.call(tab);
    tabs.insert(tabs.indexOf(source) + 1, tab);
    return tab.id;
  }

  /// "Split right": a second view of [id]'s document in the right pane.
  bool duplicateToRight(String id) {
    final copy = duplicate(id);
    if (copy == null) return false;
    showInPane(copy, 1);
    return true;
  }

  void _unsplit() {
    split.value = false;
    paneTabs[1] = null;
    paneTabs.refresh();
    focusedPane.value = 0;
  }

  /// The (x) on a pane: leaves side by side. The document stays open as a tab, except an
  /// extra view of the same document (a copy), which is closed since it only existed for the split.
  void closePane(int pane) {
    if (!split.value) return;
    final closing = tabById(paneTabs[pane]);
    if (pane == 0) paneTabs[0] = paneTabs[1];
    _unsplit();
    if (closing != null && closing.copy > 1) close(closing.id);
  }

  void setRatio(double value) => ratio.value = value.clamp(minRatio, maxRatio);

  void next() => _step(1);
  void previous() => _step(-1);

  void _step(int delta) {
    if (tabs.length < 2) return;
    final current = tabs.indexWhere((t) => t.id == activeId);
    final target = tabs[((current < 0 ? 0 : current) + delta) % tabs.length].id;
    show(target);
  }

  void hide() => visible.value = false;
}
