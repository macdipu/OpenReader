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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
  int _selected = 0;

  /// The focus ring shows only for keyboard focus, not after a click or a tap.
  bool _keyboard = FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    final keyboard = mode == FocusHighlightMode.traditional;
    if (keyboard != _keyboard && mounted) setState(() => _keyboard = keyboard);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    _listFocus.dispose();
    super.dispose();
  }

  void _select(int index) {
    final last = widget.sections.length - 1;
    setState(() => _selected = index.clamp(0, last));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _select(_selected + 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _select(_selected - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      _select(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.end) {
      _select(widget.sections.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.sections[_selected.clamp(0, widget.sections.length - 1)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: context.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Reading, privacy and storage', style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant)),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 232,
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
                const SizedBox(width: 24),
                Expanded(
                  child: ListView(
                    key: ValueKey('settings-pane-${selected.name}'),
                    padding: const EdgeInsets.only(bottom: 32),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 4),
                        child: Text(selected.title, style: context.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      selected.build(widget.controller, showLabel: false),
                    ],
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

/// One item of the desktop section list. Selected: filled background, a leading indicator bar
/// and bold text (not colour alone). Focused by keyboard: a 2px focus ring. The list is one Tab
/// stop (arrow keys move the selection), so the items themselves take no focus.
class _SectionTile extends StatelessWidget {
  final SettingsSectionId section;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;
  const _SectionTile({required this.section, required this.selected, required this.focused, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.onSecondaryContainer : context.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MergeSemantics(
        child: Semantics(
          key: ValueKey('settings-section-tile-${section.name}'),
          button: true,
          selected: selected,
          child: SettingsFocusRing(
            focused: selected && focused,
            child: InkWell(
              onTap: onTap,
              canRequestFocus: false,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.fromLTRB(4, 10, 12, 10),
                decoration: BoxDecoration(
                  color: selected ? context.secondaryContainer : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      key: selected ? const ValueKey('settings-section-indicator') : null,
                      width: 3,
                      height: 20,
                      decoration: BoxDecoration(
                        color: selected ? context.secondary : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Icon(section.icon, size: 20, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        section.title,
                        style: context.bodyMedium?.copyWith(
                          color: selected ? context.onSecondaryContainer : context.onSurface,
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
