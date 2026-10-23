import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/app_shortcuts.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../services/utilities/pptx_parser.dart';
import 'powerpoint_reader_controller.dart';

/// PowerPoint reader (CR-OPENREADER-PPTX): one slide at a time - swipe, the
/// bottom bar's arrows or the keyboard's Left/Right move between slides.
class PowerPointReaderView extends GetView<PowerPointReaderController> {
  const PowerPointReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    // Outside AppShortcuts so its focus node bubbles the arrows here; the
    // search field handles its own arrows first, so typing is unaffected.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): controller.previousSlide,
        const SingleActivator(LogicalKeyboardKey.arrowRight): controller.nextSlide,
      },
      child: AppShortcuts(
        // Ctrl/Cmd+F searches; Esc closes search, then the reader (UX-34).
        onSearch: controller.startSearching,
        onEscape: () => controller.isSearching.value ? controller.stopSearching() : Get.back(),
        child: Obx(() => Scaffold(
              appBar: _ReaderAppBar(controller: controller, searching: controller.isSearching.value),
              body: Obx(() {
                final status = controller.status.value;
                if (status.isBusy) return const LoadingView();
                if (controller.hasError.value) return _ReaderErrorView(controller: controller);
                if (status.isEmpty) {
                  return Center(child: Text('This presentation has no slides.', style: context.bodyMedium));
                }
                return Container(
                  color: context.background,
                  child: PageView.builder(
                    controller: controller.pageController,
                    itemCount: controller.slides.length,
                    onPageChanged: controller.onSlideChanged,
                    itemBuilder: (context, index) => _SlideCard(slide: controller.slides[index], number: index + 1),
                  ),
                );
              }),
              bottomNavigationBar: Obx(() => controller.slides.isEmpty || controller.hasError.value
                  ? const SizedBox.shrink()
                  : _SlideNavigationBar(controller: controller)),
            )),
      ),
    );
  }
}

class _SlideCard extends StatelessWidget {
  final PptxSlide slide;
  final int number;

  const _SlideCard({required this.slide, required this.number});

  @override
  Widget build(BuildContext context) {
    final title = slide.title;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.outlineVariant),
        ),
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) ...[
                Text(title, style: context.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
              ],
              for (final block in slide.blocks)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: _block(context, block)),
              if (title == null && slide.blocks.isEmpty)
                Text(
                  'Slide $number has no text or pictures to show.',
                  style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static int _columnCount(List<List<String>> rows) =>
      rows.fold(0, (most, row) => row.length > most ? row.length : most);

  Widget _block(BuildContext context, PptxBlock block) {
    return switch (block) {
      PptxParagraph(:final text, :final level) => Padding(
          padding: EdgeInsets.only(left: 18.0 * level),
          child: Text(text, style: context.bodyLarge),
        ),
      PptxTable(:final rows) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: context.outlineVariant),
            children: [
              for (final row in rows)
                TableRow(children: [
                  for (final cell in row)
                    Padding(padding: const EdgeInsets.all(8), child: Text(cell, style: context.bodyMedium)),
                  // Merged cells leave rows short; Table needs them even.
                  for (var i = row.length; i < _columnCount(rows); i++) const SizedBox.shrink(),
                ]),
            ],
          ),
        ),
      PptxImage(:final bytes) => Center(
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
    };
  }
}

class _SlideNavigationBar extends StatelessWidget {
  final PowerPointReaderController controller;

  const _SlideNavigationBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: context.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous slide',
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: controller.canGoPrevious ? controller.previousSlide : null,
                ),
                Text(
                  '${controller.currentSlide.value + 1} / ${controller.slides.length}',
                  style: context.labelLarge,
                ),
                IconButton(
                  tooltip: 'Next slide',
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: controller.canGoNext ? controller.nextSlide : null,
                ),
              ],
            )),
      ),
    );
  }
}

class _ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final PowerPointReaderController controller;

  /// Whether the search field (and its result bar below) is showing.
  final bool searching;

  const _ReaderAppBar({required this.controller, required this.searching});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (searching ? 40 : 0));

  @override
  Widget build(BuildContext context) {
    final accent = DocumentCategory.powerpoint.accentColor(context);
    final tint = DocumentCategory.powerpoint.tintColor(context);

    return AppBar(
      title: Obx(
        () => controller.isSearching.value
            ? TextField(
                autofocus: true,
                style: context.titleMedium,
                cursorColor: context.secondary,
                decoration: InputDecoration(
                  hintText: 'Search in slides',
                  hintStyle: context.titleMedium?.copyWith(color: context.onSurfaceVariant),
                  border: InputBorder.none,
                ),
                onChanged: controller.onSearchQueryChanged,
              )
            : Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      DocumentCategory.powerpoint.shortCode,
                      style: context.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800, fontSize: 9),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(controller.document.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
      ),
      actions: [
        Obx(
          () => controller.isSearching.value
              ? IconButton(
                  tooltip: 'Close search', icon: const Icon(Icons.close_rounded), onPressed: controller.stopSearching)
              : IconButton(
                  tooltip: 'Search in slides',
                  icon: const Icon(Icons.search_rounded),
                  onPressed: controller.startSearching),
        ),
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
          tooltip: 'More options',
          onSelected: (action) => _handle(action),
          itemBuilder: (context) => const [
            PopupMenuItem(value: _ReaderAction.share, child: Text('Share')),
            PopupMenuItem(value: _ReaderAction.openWith, child: Text('Open With')),
          ],
        ),
      ],
      bottom: searching
          ? PreferredSize(preferredSize: const Size.fromHeight(40), child: _SearchStatusBar(controller: controller))
          : null,
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

class _ReaderErrorView extends StatelessWidget {
  final PowerPointReaderController controller;

  const _ReaderErrorView({required this.controller});

  @override
  Widget build(BuildContext context) {
    // BRD §13.
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

class _SearchStatusBar extends StatelessWidget {
  final PowerPointReaderController controller;

  const _SearchStatusBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String label;
      if (controller.searchQuery.value.trim().isEmpty) {
        label = '';
      } else if (controller.matches.isEmpty) {
        label = 'No matches';
      } else {
        final slide = controller.matches[controller.currentMatch.value.clamp(0, controller.matches.length - 1)] + 1;
        label = 'Slide $slide (${controller.currentMatch.value + 1} of ${controller.matches.length} matching slides)';
      }
      return Container(
        color: context.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant))),
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
