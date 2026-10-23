import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../core/domain/models/document_category.dart';
import '../../../core/domain/models/document_model.dart';
import '../../../core/presentation/controllers/base_controller.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../services/utilities/folder_browser_service.dart';
import '../../../services/utilities/storage_access_service.dart';

/// The Browse tab (CR-OPENREADER-BROWSE): an in-app folder browser over the
/// device's storage, replacing the former scan-everything index. Shows the
/// storage roots, then one folder at a time; documents are only read from
/// disk for the folder on screen, or for an explicit subfolder search.
class BrowseController extends BaseController {
  BrowseController({FolderBrowserService? browser, StorageAccessService? storageAccess})
      : _browser = browser ?? FolderBrowserService.instance,
        _storageAccess = storageAccess ?? StorageAccessService.instance;

  final FolderBrowserService _browser;
  final StorageAccessService _storageAccess;

  final hasAccess = true.obs;
  final roots = <BrowseRoot>[].obs;

  /// The folder on screen; null shows the list of [roots].
  final currentPath = RxnString();

  /// The root the user opened. Desktop roots nest (Documents is inside
  /// Home), so back and the breadcrumb follow the one actually chosen.
  BrowseRoot? _activeRoot;
  final folders = <Directory>[].obs;
  final documents = <DocumentModel>[].obs;

  /// The OS refused to list [currentPath].
  final denied = false.obs;

  final selectedCategory = Rxn<DocumentCategory>();
  final sortMode = DocumentSortMode.nameAsc.obs;

  /// Instant name filter over the folder on screen.
  final filter = ''.obs;

  /// Subfolder search ("Search subfolders" / Search screen's "Search on
  /// device"): results replace the folder view while [showingSearch].
  final showingSearch = false.obs;
  final isSearching = false.obs;
  final searchQuery = ''.obs;
  final searchResults = <DocumentModel>[].obs;
  StreamSubscription<DocumentModel>? _search;
  Completer<void>? _searchDone;

  int _loadSession = 0;

  bool get atRoots => currentPath.value == null;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _search?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    final session = ++_loadSession;
    errorMessage.value = null;
    beginLoad();
    hasAccess.value = await _storageAccess.hasAccess();
    if (session != _loadSession) return;
    if (!hasAccess.value) {
      status.value = StateStatus.empty;
      return;
    }
    roots.assignAll(await _browser.roots());
    if (session != _loadSession) return;
    final path = currentPath.value;
    if (path == null) {
      folders.clear();
      documents.clear();
      denied.value = false;
      status.value = roots.isEmpty ? StateStatus.empty : StateStatus.success;
      return;
    }
    final listing = await _browser.list(path);
    if (session != _loadSession) return;
    folders.assignAll(listing.folders);
    documents.assignAll(listing.documents);
    denied.value = listing.denied;
    status.value = listing.folders.isEmpty && listing.documents.isEmpty ? StateStatus.empty : StateStatus.success;
  }

  Future<void> openRoot(BrowseRoot root) {
    _activeRoot = root;
    return openFolder(root.path);
  }

  Future<void> openFolder(String path) {
    closeSearch();
    filter.value = '';
    currentPath.value = path;
    return load();
  }

  Future<void> showRoots() {
    closeSearch();
    filter.value = '';
    currentPath.value = null;
    _activeRoot = null;
    return load();
  }

  /// Back/up: subfolder search first, then one folder up, then the roots
  /// list. Returns false at the roots list, so a back press can leave.
  bool goUp() {
    if (showingSearch.value) {
      closeSearch();
      return true;
    }
    final path = currentPath.value;
    if (path == null) return false;
    final root = rootOf(path);
    if (root == null || p.equals(path, root.path)) {
      unawaited(showRoots());
    } else {
      unawaited(openFolder(p.dirname(path)));
    }
    return true;
  }

  /// The root [path] is under: the one the user opened, else the longest
  /// matching root.
  BrowseRoot? rootOf(String path) {
    final active = _activeRoot;
    if (active != null && (p.equals(path, active.path) || p.isWithin(active.path, path))) return active;
    BrowseRoot? best;
    for (final root in roots) {
      if (p.equals(path, root.path) || p.isWithin(root.path, path)) {
        if (best == null || root.path.length > best.path.length) best = root;
      }
    }
    return best;
  }

  /// Root name, then each folder below it, with the path each one opens.
  List<({String name, String path})> get breadcrumb {
    final path = currentPath.value;
    if (path == null) return const [];
    final root = rootOf(path);
    if (root == null) return [(name: p.basename(path), path: path)];
    final crumbs = [(name: root.name, path: root.path)];
    var walked = root.path;
    for (final part in p.split(p.relative(path, from: root.path))) {
      if (part == '.') continue;
      walked = p.join(walked, part);
      crumbs.add((name: part, path: walked));
    }
    return crumbs;
  }

  /// The folder's documents after the format filter, name filter and sort.
  List<DocumentModel> get visibleDocuments {
    final category = selectedCategory.value;
    final needle = filter.value.trim().toLowerCase();
    final list = documents.where((d) {
      if (category != null && d.category != category) return false;
      return needle.isEmpty || d.displayName.toLowerCase().contains(needle);
    }).toList();
    list.sort(_comparator(sortMode.value));
    return list;
  }

  /// Folders matching the name filter (formats and sort don't apply).
  List<Directory> get visibleFolders {
    final needle = filter.value.trim().toLowerCase();
    if (needle.isEmpty) return folders;
    return folders.where((f) => p.basename(f.path).toLowerCase().contains(needle)).toList();
  }

  /// Format counts in the folder on screen, for the filter pills.
  Map<DocumentCategory, int> get categoryCounts {
    final counts = <DocumentCategory, int>{};
    for (final d in documents) {
      counts[d.category] = (counts[d.category] ?? 0) + 1;
    }
    return counts;
  }

  void selectCategory(DocumentCategory? category) => selectedCategory.value = category;
  void setSort(DocumentSortMode mode) => sortMode.value = mode;
  void setFilter(String value) => filter.value = value;

  /// Searches file names in the folder on screen and everything below it -
  /// or every root when at the roots list. Results stream in; [cancelSearch]
  /// stops it.
  Future<void> searchSubfolders(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    cancelSearch();
    searchQuery.value = trimmed;
    searchResults.clear();
    showingSearch.value = true;
    isSearching.value = true;
    final current = currentPath.value;
    // At the roots list, search each root once: desktop roots nest
    // (Documents is inside Home), which used to list matches twice.
    final starts = current != null
        ? [current]
        : [
            for (final r in roots)
              if (!roots.any((o) => o != r && p.isWithin(o.path, r.path))) r.path,
          ];
    final seen = <String>{};
    final done = _searchDone = Completer<void>();
    _search = _searchEach(starts, trimmed).listen(
      (document) {
        if (!seen.add(document.path)) return;
        searchResults.add(document);
        // One cap for the whole search, not per root.
        if (searchResults.length >= FolderBrowserService.maxSearchResults) cancelSearch();
      },
      onDone: () {
        isSearching.value = false;
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: false,
    );
    return done.future;
  }

  Stream<DocumentModel> _searchEach(List<String> starts, String query) async* {
    for (final start in starts) {
      yield* _browser.search(start, query);
    }
  }

  void cancelSearch() {
    _search?.cancel();
    _search = null;
    isSearching.value = false;
    // A cancelled stream never reports done; finish the caller's future.
    final done = _searchDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  void closeSearch() {
    cancelSearch();
    showingSearch.value = false;
    searchResults.clear();
  }

  /// Browse's "Grant Access" - falls back to system settings once the OS
  /// stops prompting.
  Future<void> requestAccess() async {
    if (await _storageAccess.requestOrOpenSettings()) await load();
  }

  /// After a delete, the folder (or search results) no longer has it.
  void removeDocument(String id) {
    documents.removeWhere((d) => d.id == id);
    searchResults.removeWhere((d) => d.id == id);
  }

  static int Function(DocumentModel, DocumentModel) _comparator(DocumentSortMode mode) {
    int byName(DocumentModel a, DocumentModel b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    return switch (mode) {
      DocumentSortMode.nameAsc => byName,
      DocumentSortMode.nameDesc => (a, b) => byName(b, a),
      DocumentSortMode.newestFirst => (a, b) => b.modifiedAt.compareTo(a.modifiedAt),
      DocumentSortMode.oldestFirst => (a, b) => a.modifiedAt.compareTo(b.modifiedAt),
      DocumentSortMode.largestFirst => (a, b) => b.sizeBytes.compareTo(a.sizeBytes),
      DocumentSortMode.smallestFirst => (a, b) => a.sizeBytes.compareTo(b.sizeBytes),
    };
  }
}
