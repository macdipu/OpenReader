import 'package:flutter/material.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../core/presentation/utils/platform_info.dart';
import '../../../../core/presentation/widgets/key_cap.dart';
import 'hover_surface.dart';

/// "Cmd" glyph on macOS, "Ctrl+" elsewhere, before a key: `⌘F`, `Ctrl+F`.
String shortcutLabel(String key) => PlatformInfo.isMacOS ? '⌘$key' : 'Ctrl+$key';

/// Desktop Home's main-pane toolbar: the page title, the search field, and the inspector toggle.
/// No primary action here; Open file is the sidebar's.
class HomeToolbar extends StatelessWidget {
  final VoidCallback onSearch;

  /// Null disables the toggle (nothing to inspect).
  final VoidCallback? onToggleInspector;
  final bool inspectorShown;

  const HomeToolbar({super.key, required this.onSearch, required this.onToggleInspector, required this.inspectorShown});

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final toggleLabel = '${inspectorShown ? 'Hide' : 'Show'} details (${shortcutLabel('I')})';
    return Container(
      constraints: const BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.outlineVariant))),
      child: Row(
        children: [
          Text(
            'Home',
            style: context.headlineLarge?.copyWith(fontWeight: FontWeight.w600, color: context.onSurface),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: HomeSearchField(onTap: onSearch),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: const ValueKey('home-inspector-toggle'),
            tooltip: toggleLabel,
            isSelected: inspectorShown,
            onPressed: onToggleInspector,
            icon: const Icon(Icons.view_sidebar_outlined),
            selectedIcon: const Icon(Icons.view_sidebar_rounded),
          ),
        ],
      ),
    );
  }
}

/// A search field that opens the Search screen (the same as Ctrl/Cmd+F), with the shortcut on
/// a key cap.
class HomeSearchField extends StatelessWidget {
  final VoidCallback onTap;

  const HomeSearchField({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverSurface(
      key: const ValueKey('home-search-field'),
      onTap: onTap,
      semanticLabel: 'Search documents',
      builder: (context, states) => AnimatedContainer(
        duration: homeMotion,
        curve: homeCurve,
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: states.hovered ? context.surfaceContainer : context.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: focusRing(context, states, idle: context.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: context.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Search documents',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.bodyMedium?.copyWith(color: context.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 8),
            KeyCap(shortcutLabel('F'), dense: true),
          ],
        ),
      ),
    );
  }
}
