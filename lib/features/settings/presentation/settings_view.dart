import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/presentation/theme/theme_extensions.dart';
import '../../../core/presentation/utils/screen_utils.dart';
import 'settings_controller.dart';
import 'sections/settings_widgets.dart';
import 'settings_sections.dart';

/// Settings & Storage (DESIGN_SPEC.md #01). Phones and narrow windows (under 900px) get one
/// column of sections; wide windows get a section list on the left (arrow keys move between
/// sections, Tab moves through the controls) and the chosen section on the right. Which sections
/// appear, and their order, depends on the platform (see [settingsSectionsForPlatform]).
class SettingsView extends GetView<SettingsController> {
  /// True when it is a page of the shell (wide windows): no app bar of its own, the sidebar stays.
  final bool embedded;

  const SettingsView({super.key, this.embedded = false});

  /// Width from which Settings shows two panes.
  static const twoPaneBreakpoint = 900.0;

  /// Two panes: the section list's width and the pane content's maximum width.
  static const sectionListWidth = 220.0;
  static const paneMaxWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    final wide = context.screenDimensions.width >= twoPaneBreakpoint;
    final sections = settingsSectionsForPlatform();

    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Settings')),
      body: wide
          ? ContentConstraint(
              maxWidth: 1040,
              child: _TwoPane(controller: controller, sections: sections),
            )
          : ContentConstraint(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [for (final id in sections) id.build(controller, showLabel: true)],
              ),
            ),
    );
  }
}

class _TwoPane extends StatefulWidget {
  final SettingsController controller;
  final List<SettingsSectionId> sections;
  const _TwoPane({required this.controller, required this.sections});

  @override
  State<_TwoPane> createState() => _TwoPaneState();
}

class _TwoPaneState extends State<_TwoPane> {
  final _listFocus = FocusNode(debugLabel: 'settings section list');

  /// The pane's scroll position: it does not keep an offset per section and goes back to the top
  /// whenever the section changes.
  final _paneScroll = ScrollController(keepScrollOffset: false);
  int _selected = 0;

  /// Whether Settings was on screen at the last dependency change (the shell keeps it mounted in an
  /// IndexedStack while another page shows).
  bool? _wasVisible;

  /// The focus ring shows only for keyboard focus, not after a click or a tap.
  bool _keyboard = FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When Settings comes on screen, put keyboard focus on the section list (unless something in
    // Settings already has it), so Up/Down work at once and Tab goes on into the pane.
    final visible = Visibility.of(context);
    if (visible && _wasVisible != true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !Visibility.of(context)) return;
        final focused = FocusManager.instance.primaryFocus;
        final insideSettings = focused != null && focused.context != null && _isInside(focused.context!);
        if (!insideSettings) _listFocus.requestFocus();
      });
    }
    _wasVisible = visible;
  }

  bool _isInside(BuildContext other) {
    if (identical(other, context)) return true;
    var inside = false;
    other.visitAncestorElements((e) {
      inside = identical(e, context);
      return !inside;
    });
    return inside;
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    final keyboard = mode == FocusHighlightMode.traditional;
    if (keyboard != _keyboard && mounted) setState(() => _keyboard = keyboard);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    _listFocus.dispose();
    _paneScroll.dispose();
    super.dispose();
  }

  void _select(int index) {
    final next = index.clamp(0, widget.sections.length - 1);
    if (next == _selected) return;
    setState(() => _selected = next);
    if (_paneScroll.hasClients) _paneScroll.jumpTo(0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _select(_selected + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _select(_selected - 1);
    } else if (key == LogicalKeyboardKey.home) {
      _select(0);
    } else if (key == LogicalKeyboardKey.end) {
      _select(widget.sections.length - 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.sections[_selected.clamp(0, widget.sections.length - 1)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Settings',
                key: const ValueKey('settings-page-title'),
                style: context.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: SettingsView.sectionListWidth,
                  // One Tab stop: the list itself takes focus (a click on an item focuses it too)
                  // and Up/Down/Home/End move the selection.
                  child: Focus(
                    focusNode: _listFocus,
                    onKeyEvent: _onKey,
                    child: ListenableBuilder(
                      listenable: _listFocus,
                      builder: (context, _) => ListView(
                        key: const ValueKey('settings-section-list'),
                        children: [
                          for (var i = 0; i < widget.sections.length; i++)
                            _SectionTile(
                              section: widget.sections[i],
                              selected: i == _selected,
                              focused: _listFocus.hasFocus && _keyboard,
                              onTap: () {
                                _select(i);
                                _listFocus.requestFocus();
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                // The pane: at most 720px wide, left-aligned. Its heading stays above the scrolling
                // content, so it is never scrolled out of view or clipped.
                Expanded(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: SettingsView.paneMaxWidth),
                      child: Column(
                        key: ValueKey('settings-pane-${selected.name}'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 4, bottom: 12),
                            child: Semantics(
                              header: true,
                              child: Text(
                                selected.title,
                                key: const ValueKey('settings-pane-heading'),
                                style: context.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              key: const ValueKey('settings-pane-scroll'),
                              controller: _paneScroll,
                              padding: const EdgeInsets.only(bottom: 32),
                              children: [selected.build(widget.controller, showLabel: false)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One item of the desktop section list. Selected: a light fill, a leading indicator bar and bold
/// text (not colour alone). Focused by keyboard: a 2px focus ring. The list is one Tab stop (arrow
/// keys move the selection), so the items themselves take no focus.
class _SectionTile extends StatelessWidget {
  final SettingsSectionId section;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;
  const _SectionTile({required this.section, required this.selected, required this.focused, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.onSurface : context.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MergeSemantics(
        child: Semantics(
          key: ValueKey('settings-section-tile-${section.name}'),
          button: true,
          selected: selected,
          child: SettingsFocusRing(
            focused: selected && focused,
            radius: 8,
            child: InkWell(
              onTap: onTap,
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding: const EdgeInsets.fromLTRB(2, 8, 10, 8),
                decoration: BoxDecoration(
                  color: selected ? context.surfaceContainerHigh : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      key: selected ? const ValueKey('settings-section-indicator') : null,
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: selected ? context.secondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(section.icon, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.title,
                        style: context.bodyMedium?.copyWith(
                          color: context.onSurface,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
