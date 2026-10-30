import 'package:flutter/material.dart';
import '../../../core/presentation/widgets/reader/reader_safe_zone.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/domain/models/document_category.dart';
import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/state_status.dart';
import '../../../core/presentation/widgets/app_shortcuts.dart';
import '../../../core/presentation/widgets/loading_view/loading_view.dart';
import '../../../core/presentation/widgets/reader/reader_preview_strip.dart';
import '../../../core/presentation/widgets/reader/reader_night_mode_view.dart';
import '../../../core/presentation/widgets/reader/reader_toolbar.dart';
import 'package:universal_document_viewer/slides.dart';
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
              body: ReaderFullscreenScope(
                controller: controller,
                child: Obx(() {
                final status = controller.status.value;
                if (status.isBusy) return const LoadingView();
                if (controller.hasError.value) return _ReaderErrorView(controller: controller);
                if (status.isEmpty) {
                  return Center(child: Text('This presentation has no slides.', style: context.bodyMedium));
                }
                return ReaderSafeZone(kind: ReaderContent.slides, child: Container(color: context.background, child: SlidesView(controller: controller.deck)));
              }),
              ),
              bottomNavigationBar: controller.isFullscreen.value ||
                      controller.status.value.isBusy ||
                      controller.status.value.isEmpty ||
                      controller.hasError.value
                  ? null
                  : _SlidesToolbar(controller: controller),
            ))))),
      ),
    );
  }
}

/// Previews · ‹ Slide x of y › · zoom · full screen.
class _SlidesToolbar extends StatelessWidget {
  final PowerPointReaderController controller;

  const _SlidesToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final deck = controller.deck;
    return ListenableBuilder(
      listenable: deck,
      builder: (context, _) => Obx(() => ReaderBottomBar(
        above: controller.showPreviews.value
            ? ReaderPreviewStrip(
                count: deck.slides.length,
                current: deck.currentSlide + 1,
                onSelected: controller.goToSlide,
                itemLabel: 'Slide',
                itemWidth: 110,
                previewBuilder: (context, number) => _SlidePreview(slide: deck.slides[number - 1], number: number),
              )
            : null,
        children: [
          ReaderPreviewsButton(
            tooltip: 'Slide thumbnails',
            showing: controller.showPreviews.value,
            onPressed: controller.togglePreviews,
          ),
          ReaderToolbarButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous slide',
            onPressed: deck.canGoPrevious ? controller.previousSlide : null,
          ),
          ReaderPositionButton(
            label: 'Slide ${deck.currentSlide + 1} of ${deck.slides.length}',
            onPressed: () async {
              final slide = await showGoToNumberDialog(
                context,
                title: 'Go to slide',
                current: deck.currentSlide + 1,
                max: deck.slides.length,
              );
              if (slide != null) controller.goToSlide(slide);
            },
          ),
          ReaderToolbarButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next slide',
            onPressed: deck.canGoNext ? controller.nextSlide : null,
          ),
          ReaderZoomButtons(
            onZoomOut: deck.canZoomOut ? controller.zoomOut : null,
            onZoomIn: deck.canZoomIn ? controller.zoomIn : null,
          ),
          ReaderNightModeButton(on: controller.nightMode.value, onPressed: controller.toggleNightMode),
          ReaderFullscreenButton(onPressed: controller.toggleFullscreen),
        ],
      )),
    );
  }
}

/// A slide drawn at a fixed size and scaled down, for the previews.
class _SlidePreview extends StatelessWidget {
  final PptxSlide slide;
  final int number;

  const _SlidePreview({required this.slide, required this.number});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: FittedBox(
          child: SizedBox(
            width: 400,
            height: 300,
            // The slide's own size, whatever the reader's zoom.
            child: MediaQuery.withNoTextScaling(child: SlideCard(slide: slide, number: number)),
          ),
        ),
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
                // Enter steps to the next match; the field keeps focus to press again.
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => controller.goToNextMatch(),
                onEditingComplete: () {},
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
          tooltip: 'More actions',
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
    // Search can open before the file has loaded; the deck exists after.
    final deck = controller.deckOrNull;
    if (deck == null) return const SizedBox.shrink();
    return ListenableBuilder(
        listenable: deck,
        builder: (context, _) {
          final status = DocumentViewerStrings.of(context).searchStatus(deck.searchState.value);
          final match = deck.currentSlideMatch;
          final label = match == null ? status : '$status (slide ${match.slide + 1})';
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
