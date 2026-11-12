import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import 'package:universal_document_viewer/spreadsheet.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/reader/reader_night_mode_view.dart';
import '../../../core/presentation/widgets/reader/reader_toolbar.dart';
import '../../../core/presentation/widgets/reader/sheet_reader_toolbar.dart';
import 'excel_reader_controller.dart';
import 'widgets/sheet_formula_bar.dart';
import '../../../core/presentation/utils/screen_utils.dart';
import '../../../core/presentation/widgets/app_shortcuts.dart';

/// BRD §9.12 Excel Reader Screen.
///
/// Renders universal_document_viewer's spreadsheet engine (see `ExcelReaderController`'s
/// own doc comment) through [SpreadsheetView] - shared with the CSV reader since
/// `FEATURE-OPENREADER-P4` - built directly on the engine's parsed cell model.
///
/// Styled per DESIGN_SPEC.md #05/#15 (Excel Viewer, light + AMOLED): the
/// XLSX format accent (mint/emerald) marks the active sheet tab and header
/// chip, matching the "tertiary" role used for spreadsheets across the app.
class ExcelReaderView extends GetView<ExcelReaderController> {
  /// Set when the reader is a workspace tab: its controller is registered under this tag.
  final String? tabTag;

  const ExcelReaderView({super.key, this.tabTag});

  @override
  String? get tag => tabTag;

  @override
  Widget build(BuildContext context) {
    // Scaffold reads appBar.preferredSize only when it builds, so it is rebuilt
    // on search toggle to let the bar collapse back to toolbar height.
    return AppShortcuts(
      // Ctrl/Cmd+F searches; Esc closes search, then the reader (UX-34).
      onSearch: controller.startSearching,
      onEscape: controller.escape,
      child: Obx(() => ReaderNightModeView(
      // The whole reader, bars included, goes dark at night.
      enabled: controller.nightMode.value,
      // A context under the night theme for the whole screen; its own Obx,
      // since the builder runs after the outer one has finished.
      child: Builder(builder: (context) => Obx(() => Scaffold(
      appBar: controller.isFullscreen.value
          ? null
          : _ReaderAppBar(controller: controller, searching: controller.isSearching.value),
      bottomNavigationBar: controller.isFullscreen.value || !controller.status.value.isSuccess
          ? null
          : SheetReaderToolbar(controller: controller),
      body: ReaderFullscreenScope(
        controller: controller,
        child: Obx(() {
        if (controller.status.value.isBusy) return const LoadingView();
        if (controller.status.value.isError) return _ReaderErrorView(controller: controller);
        final sheetIndex = controller.activeSheetIndex.value;
        // Phones (and short windows, e.g. a phone on its side): the name
        // bar only while a cell is selected, and a thinner frame around
        // the grid; tablets and desktop: always.
        final compact = context.isCompactScreen || context.isShortScreen;
        // Landscape phones: keep the grid clear of a notch or cut-out.
        return SafeArea(
          top: false,
          bottom: false,
          child: Column(
          children: [
            _UnshownNotice(controller: controller),
            SheetFormulaBar(sheet: controller.sheet, alwaysShown: !compact),
            Expanded(
              child: Container(
                margin: EdgeInsets.all(compact ? 4 : 8),
                decoration: BoxDecoration(
                  border: Border.all(color: context.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                // The grid draws its own scrollbars; the format's accent colours its selection.
                child: SpreadsheetView(
                  key: ValueKey(sheetIndex),
                  controller: controller.sheet,
                  emptyMessage: 'Empty workbook',
                  selectionColor: DocumentCategory.excel.accentColor(context),
                ),
              ),
            ),
            _SheetTabBar(controller: controller),
          ],
          ),
        );
      }),
      ),
    ))))),
    );
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ExcelReaderController controller;

  /// Whether the search field (and its result bar below) is showing.
  final bool searching;

  const _ReaderAppBar({required this.controller, required this.searching});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (searching ? 40 : 0));

  @override
  Widget build(BuildContext context) {
    final accent = DocumentCategory.excel.accentColor(context);
    final tint = DocumentCategory.excel.tintColor(context);

    return AppBar(
      title: Obx(
        () => controller.isSearching.value
            ? TextField(
                autofocus: true,
                style: context.titleMedium,
                decoration: InputDecoration(
                  hintText: 'Search cells',
                  border: InputBorder.none,
                  hintStyle: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
                ),
                onChanged: controller.search,
                // Enter steps to the next match; the field keeps focus to press again.
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => controller.goToNextMatch(),
                onEditingComplete: () {},
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      DocumentCategory.excel.shortCode,
                      style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      controller.document.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ReadOnlyMark(labelled: !context.isCompactScreen),
                ],
              ),
      ),
      actions: [
        Obx(
          () => IconButton(
            tooltip: controller.isSearching.value
                ? 'Close search'
                : controller.searchOptions.value.allSheets && controller.sheetNames.length > 1
                    ? 'Search in workbook'
                    : 'Search in sheet',
            icon: Icon(controller.isSearching.value ? Icons.close_rounded : Icons.search_rounded),
            onPressed: controller.isSearching.value ? controller.stopSearching : controller.startSearching,
          ),
        ),
        // Phones keep the bar to search and More; Favorite moves into More.
        if (!context.isCompactScreen)
        Obx(
          () => IconButton(
            tooltip: controller.isFavorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(
              controller.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: controller.isFavorite ? context.secondary : null,
            ),
            onPressed: controller.toggleFavorite,
          ),
        ),
        PopupMenuButton<_ReaderAction>(
          tooltip: 'More actions',
          onSelected: (action) => _handle(context, action),
          itemBuilder: (context) => [
            if (context.isCompactScreen)
              PopupMenuItem(
                value: _ReaderAction.favorite,
                child: Text(controller.isFavorite ? 'Remove from favorites' : 'Add to favorites'),
              ),
            const PopupMenuItem(value: _ReaderAction.share, child: Text('Share')),
            const PopupMenuItem(value: _ReaderAction.openWith, child: Text('Open With')),
          ],
        ),
      ],
      bottom: searching
          ? PreferredSize(preferredSize: const Size.fromHeight(40), child: _SearchStatusBar(controller: controller))
          : null,
    );
  }

  void _handle(BuildContext context, _ReaderAction action) {
    switch (action) {
      case _ReaderAction.favorite:
        controller.toggleFavorite();
      case _ReaderAction.share:
        controller.share();
      case _ReaderAction.openWith:
        controller.openWith();
    }
  }
}

enum _ReaderAction { favorite, share, openWith }

/// Says the reader can't change the file: a lock, with "Read-only" beside
/// it where there is room.
class _ReadOnlyMark extends StatelessWidget {
  final bool labelled;

  const _ReadOnlyMark({required this.labelled});

  @override
  Widget build(BuildContext context) {
    final color = context.onSurfaceVariant;
    return Tooltip(
      message: 'Read-only: this reader never changes the file',
      child: Semantics(
        label: 'Read-only',
        excludeSemantics: true,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: labelled ? 8 : 4, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: context.outlineVariant),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: color),
              if (labelled) ...[
                const SizedBox(width: 4),
                Text('Read-only', style: context.labelSmall?.copyWith(color: color)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchStatusBar extends StatelessWidget {
  final ExcelReaderController controller;

  const _SearchStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isSearching.value) return const SizedBox.shrink();
      final String label;
      if (controller.searchQuery.value.isEmpty) {
        label = '';
      } else if (controller.searchInProgress.value) {
        label = 'Searching...';
      } else if (controller.matches.isEmpty) {
        // Zero matches in readable text. BRD's 'No searchable text found'
        // is reserved for text-less (scanned) PDFs.
        label = 'No matches';
      } else {
        final sheet = controller.currentMatchSheetName;
        label =
            '${controller.currentMatchIndex.value + 1} of ${controller.matches.length}${sheet == null ? '' : ' · $sheet'}';
      }
      return Container(
        color: context.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
              ),
            ),
            _SearchOptionsButton(controller: controller),
            IconButton(
              tooltip: 'Previous match',
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              color: context.onSurfaceVariant,
              onPressed: controller.matches.isNotEmpty ? controller.goToPrevMatch : null,
            ),
            IconButton(
              tooltip: 'Next match',
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              color: context.onSurfaceVariant,
              onPressed: controller.matches.isNotEmpty ? controller.goToNextMatch : null,
            ),
          ],
        ),
      );
    });
  }
}

enum _SearchOption { matchCase, wholeCell, inFormulas, allSheets }

/// Excel's Find options; the icon is filled while any differs from the
/// default.
class _SearchOptionsButton extends StatelessWidget {
  final ExcelReaderController controller;

  const _SearchOptionsButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    final options = controller.searchOptions.value;
    final changed = options.matchCase || options.wholeCell || options.inFormulas;
    return PopupMenuButton<_SearchOption>(
      tooltip: 'Search options',
      icon: Icon(changed ? Icons.tune_rounded : Icons.tune_outlined, color: context.onSurfaceVariant),
      onSelected: (option) => controller.setSearchOptions(switch (option) {
        _SearchOption.matchCase => options.copyWith(matchCase: !options.matchCase),
        _SearchOption.wholeCell => options.copyWith(wholeCell: !options.wholeCell),
        _SearchOption.inFormulas => options.copyWith(inFormulas: !options.inFormulas),
        _SearchOption.allSheets => options.copyWith(allSheets: !options.allSheets),
      }),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
            value: _SearchOption.matchCase, checked: options.matchCase, child: const Text('Match case')),
        CheckedPopupMenuItem(
          value: _SearchOption.wholeCell,
          checked: options.wholeCell,
          child: const Text('Match entire cell'),
        ),
        CheckedPopupMenuItem(
          value: _SearchOption.inFormulas,
          checked: options.inFormulas,
          child: const Text('Search formulas'),
        ),
        if (controller.sheetNames.length > 1)
          CheckedPopupMenuItem(
            value: _SearchOption.allSheets,
            checked: options.allSheets,
            child: const Text('All sheets'),
          ),
      ],
    );
  }
}

class _SheetTabBar extends StatelessWidget {
  final ExcelReaderController controller;

  const _SheetTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final names = controller.sheetNames.toList();
      final hidden = controller.hiddenSheetNames.toList();
      if (names.length <= 1 && hidden.isEmpty) return const SizedBox.shrink();
      final accent = DocumentCategory.excel.accentColor(context);
      final active = controller.activeSheetIndex.value;
      // The bar's background runs under the system gesture/navigation bar,
      // but the tabs sit above it - they used to be drawn underneath it.
      return Container(
        decoration: BoxDecoration(
          color: context.surfaceContainerLowest,
          border: Border(top: BorderSide(color: context.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: context.scaledExtent(44),
            child: Row(
              children: [
                // Every sheet in one list, for workbooks with more tabs than fit.
                IconButton(
                  tooltip: 'All sheets',
                  icon: const Icon(Icons.menu_rounded),
                  color: context.onSurfaceVariant,
                  onPressed: () => _showSheetPicker(context, controller),
                ),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: names.length,
                    itemBuilder: (context, index) {
                      final selected = index == active;
                      return InkWell(
                        onTap: () => controller.switchSheet(index),
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: selected ? context.surfaceContainerHigh : null,
                            border: Border(bottom: BorderSide(color: selected ? accent : Colors.transparent, width: 2)),
                          ),
                          child: Text(
                            names[index],
                            style: selected
                                ? context.bodySmall?.copyWith(color: accent, fontWeight: FontWeight.bold)
                                : context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (hidden.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Tooltip(
                      message: 'Sheets hidden by the author',
                      child: ActionChip(
                        avatar: Icon(Icons.visibility_off_outlined, size: 16, color: context.onSurfaceVariant),
                        label: Text('${hidden.length} hidden'),
                        labelStyle: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showSheetPicker(context, controller),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Lists every sheet (the tabs can scroll out of sight in a big workbook)
/// and names the hidden ones, which can't be opened here.
void _showSheetPicker(BuildContext context, ExcelReaderController controller) {
  final names = controller.sheetNames.toList();
  final hidden = controller.hiddenSheetNames.toList();
  final active = controller.activeSheetIndex.value;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text('Sheets (${names.length})', style: sheetContext.titleSmall)),
            for (var i = 0; i < names.length; i++)
              ListTile(
                leading: Icon(i == active ? Icons.check_rounded : Icons.grid_on_rounded),
                title: Text(names[i]),
                selected: i == active,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  controller.switchSheet(i);
                },
              ),
            if (hidden.isNotEmpty) ...[
              const Divider(),
              ListTile(
                title: Text('Hidden by the author (${hidden.length})', style: sheetContext.titleSmall),
                subtitle: const Text('Hidden sheets are not shown in this reader.'),
              ),
              for (final name in hidden)
                ListTile(
                  enabled: false,
                  leading: const Icon(Icons.visibility_off_outlined),
                  title: Text(name),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Says what the sheet on screen holds that the reader doesn't draw
/// (pictures, charts, validation...), instead of leaving it out silently.
class _UnshownNotice extends StatelessWidget {
  final ExcelReaderController controller;

  const _UnshownNotice({required this.controller});

  static const _labels = {
    UnshownContent.chartSheet: 'this chart sheet',
    UnshownContent.drawings: 'pictures, charts and shapes',
    UnshownContent.tables: 'table styles and filter buttons',
    UnshownContent.pivotTables: 'pivot table features (saved values are shown)',
    UnshownContent.dataValidation: 'drop-down lists and input rules',
    UnshownContent.conditionalFormatting: 'some conditional formatting',
    UnshownContent.sparklines: 'sparklines',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.showUnshownNotice) return const SizedBox.shrink();
      final items = [
        for (final entry in _labels.entries)
          if (controller.unshownContent.contains(entry.key)) entry.value,
      ];
      return Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: context.surfaceContainerLow,
          border: Border.all(color: context.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: context.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not shown: ${items.join(', ')}.',
                style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded, size: 18),
              color: context.onSurfaceVariant,
              onPressed: controller.dismissUnshownNotice,
            ),
          ],
        ),
      );
    });
  }
}

class _ReaderErrorView extends StatelessWidget {
  final ExcelReaderController controller;

  const _ReaderErrorView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: context.error),
            const SizedBox(height: 16),
            Text(
              controller.errorMessage.value ?? 'This document may be damaged or incomplete.',
              textAlign: TextAlign.center,
              style: context.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: controller.exitReader, child: const Text('Close')),
                const SizedBox(width: 8),
                FilledButton(onPressed: controller.openWith, child: const Text('Try another app')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
