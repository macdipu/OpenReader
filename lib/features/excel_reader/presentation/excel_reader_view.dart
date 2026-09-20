import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/cell_grid/cell_grid.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import 'excel_reader_controller.dart';

/// BRD §9.12 Excel Reader Screen.
///
/// `excel_plus` (the parsing library, see `ExcelReaderController`'s own doc
/// comment) ships no grid widget, so [CellGrid] - shared with the CSV reader
/// since `FEATURE-OPENREADER-P4` - is first-party OpenReader UI built directly on
/// its parsed cell model.
///
/// Styled per DESIGN_SPEC.md #05/#15 (Excel Viewer, light + AMOLED): the
/// XLSX format accent (mint/emerald) marks the active sheet tab and header
/// chip, matching the "tertiary" role used for spreadsheets across the app.
class ExcelReaderView extends GetView<ExcelReaderController> {
  const ExcelReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _ReaderAppBar(controller: controller),
      body: Obx(() {
        if (controller.status.value.isBusy) return const LoadingView();
        if (controller.status.value.isError) return _ReaderErrorView(controller: controller);
        return Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: context.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: CellGrid(controller: controller, emptyMessage: 'Empty workbook'),
              ),
            ),
            _SheetTabBar(controller: controller),
          ],
        );
      }),
    );
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ExcelReaderController controller;

  const _ReaderAppBar({required this.controller});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 40);

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
                ],
              ),
      ),
      actions: [
        Obx(
          () => IconButton(
            icon: Icon(controller.isSearching.value ? Icons.close_rounded : Icons.search_rounded),
            onPressed: controller.isSearching.value ? controller.stopSearching : controller.startSearching,
          ),
        ),
        Obx(
          () => IconButton(
            icon: Icon(
              controller.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: controller.isFavorite ? context.secondary : null,
            ),
            onPressed: controller.toggleFavorite,
          ),
        ),
        PopupMenuButton<_ReaderAction>(
          onSelected: (action) => _handle(action),
          itemBuilder: (context) => const [
            PopupMenuItem(value: _ReaderAction.share, child: Text('Share')),
            PopupMenuItem(value: _ReaderAction.openWith, child: Text('Open With')),
          ],
        ),
      ],
      bottom: PreferredSize(preferredSize: const Size.fromHeight(40), child: _SearchStatusBar(controller: controller)),
    );
  }

  void _handle(_ReaderAction action) {
    switch (action) {
      case _ReaderAction.share:
        controller.share();
      case _ReaderAction.openWith:
        controller.openWith();
    }
  }
}

enum _ReaderAction { share, openWith }

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
      } else if (controller.matches.isEmpty) {
        // BRD §13.
        label = 'No searchable text found.';
      } else {
        label = '${controller.currentMatchIndex.value + 1} of ${controller.matches.length} result(s)';
      }
      return Container(
        color: context.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant))),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              color: context.onSurfaceVariant,
              onPressed: controller.matches.isNotEmpty ? controller.goToPrevMatch : null,
            ),
            IconButton(
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

class _SheetTabBar extends StatelessWidget {
  final ExcelReaderController controller;

  const _SheetTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.sheetNames.length <= 1) return const SizedBox.shrink();
      final accent = DocumentCategory.excel.accentColor(context);
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: context.surfaceContainerLowest,
          border: Border(top: BorderSide(color: context.outlineVariant)),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: controller.sheetNames.length,
          itemBuilder: (context, index) {
            final selected = index == controller.activeSheetIndex.value;
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
                  controller.sheetNames[index],
                  style: selected
                      ? context.bodySmall?.copyWith(color: accent, fontWeight: FontWeight.bold)
                      : context.bodySmall?.copyWith(color: context.onSurfaceVariant),
                ),
              ),
            );
          },
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
                TextButton(onPressed: () => Get.back(), child: const Text('Close')),
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
