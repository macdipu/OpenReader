import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/presentation/theme/theme_extensions.dart';
import '../../core/presentation/utils/platform_info.dart';
import '../../core/presentation/utils/screen_utils.dart';
import '../../features/workspace/presentation/workspace_controller.dart';
import 'app_shell_controller.dart';

/// The shell's destinations, shared by the phone bottom bar and the sidebar.
const shellDestinations = [
  (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  (
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder_rounded,
    label: 'Browse'
  ),
  (
    icon: Icons.star_outline_rounded,
    activeIcon: Icons.star_rounded,
    label: 'Library'
  ),
];

/// Desktop / tablet sidebar: brand, primary "Open file" action, destinations
/// and Settings pinned to the bottom. Collapses to an icon rail on narrower
/// windows.
class DesktopSidebar extends StatelessWidget {
  final AppShellController controller;
  final bool extended;

  /// The [<] / [>] button at the top.
  final VoidCallback onToggle;

  const DesktopSidebar(
      {super.key,
      required this.controller,
      required this.extended,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // A tablet has no keyboard shortcut to advertise.
    final shortcut =
        PlatformInfo.isMobile ? '' : (PlatformInfo.isMacOS ? '⌘O' : 'Ctrl+O');
    // Keep clear of the status bar and the gesture bar on Android tablets and foldables.
    final insets = MediaQuery.paddingOf(context);
    // A phone on its side is short: drop the brand and tighten the spacing.
    final short = context.isShortScreen;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: extended ? 252 : 76,
      color: context.surfaceContainerLowest,
      padding: EdgeInsets.fromLTRB(
          extended ? 14 : 10,
          (short ? 8 : 16) + insets.top,
          extended ? 14 : 10,
          (short ? 8 : 16) + insets.bottom),
      // Scrolls if even the compact rail does not fit (a very short window).
      // Labels appear only once the animated width has room for them, so expanding never clips.
      child: LayoutBuilder(builder: (context, constraints) {
        final extended = this.extended && constraints.maxWidth >= 190;
        return CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SidebarBrand(
                      extended: extended,
                      onToggle: onToggle,
                      showMark: !short || extended),
                  SizedBox(height: short ? 8 : 20),
                  if (extended)
                    FilledButton(
                      onPressed: controller.pickAndOpenFile,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.file_open_outlined, size: 20),
                          const SizedBox(width: 10),
                          const Text('Open file'),
                          const Spacer(),
                          if (shortcut.isNotEmpty)
                            Text(shortcut,
                                style: context.labelSmall?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.75))),
                        ],
                      ),
                    )
                  else
                    Tooltip(
                      message: shortcut.isEmpty
                          ? 'Open file'
                          : 'Open file ($shortcut)',
                      child: FilledButton(
                        onPressed: controller.pickAndOpenFile,
                        style: FilledButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Icon(Icons.file_open_outlined, size: 22),
                      ),
                    ),
                  SizedBox(height: short ? 12 : 24),
                  if (extended)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Text('BROWSE',
                          style: context.labelSmall?.copyWith(
                              color: context.onSurfaceVariant,
                              letterSpacing: 1.2)),
                    ),
                  Obx(() {
                    final workspace = Get.find<WorkspaceController>();
                    final inWorkspace =
                        workspace.visible.value && workspace.tabs.isNotEmpty;
                    final openCount = workspace.tabs.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < shellDestinations.length; i++)
                          _SidebarItem(
                            icon: shellDestinations[i].icon,
                            activeIcon: shellDestinations[i].activeIcon,
                            label: shellDestinations[i].label,
                            selected: !inWorkspace &&
                                controller.currentIndex.value == i,
                            extended: extended,
                            onTap: () => controller.changeTab(i),
                          ),
                        // Documents that are open in tabs, one click from anywhere.
                        if (openCount > 0)
                          _SidebarItem(
                            icon: Icons.tab_outlined,
                            activeIcon: Icons.tab_rounded,
                            label: 'Open documents',
                            badge: '$openCount',
                            selected: inWorkspace,
                            extended: extended,
                            onTap: () => workspace.visible.value = true,
                          ),
                      ],
                    );
                  }),
                  const Spacer(),
                  Divider(
                      height: short ? 12 : 24, color: context.outlineVariant),
                  Obx(() {
                    final workspace = Get.find<WorkspaceController>();
                    final inWorkspace =
                        workspace.visible.value && workspace.tabs.isNotEmpty;
                    return _SidebarItem(
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings_rounded,
                      label: 'Settings',
                      selected: !inWorkspace &&
                          controller.currentIndex.value ==
                              AppShellController.settingsIndex,
                      extended: extended,
                      // A page of the shell, so the sidebar and the open tabs stay where they are.
                      onTap: () => controller
                          .changeTab(AppShellController.settingsIndex),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  final bool extended;
  final VoidCallback onToggle;

  /// Short windows drop the logo and keep only the toggle.
  final bool showMark;

  const _SidebarBrand(
      {required this.extended, required this.onToggle, required this.showMark});

  @override
  Widget build(BuildContext context) {
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.asset('assets/icon/icon.png',
          width: 34, height: 34, filterQuality: FilterQuality.medium),
    );
    final toggle = _SidebarToggle(extended: extended, onPressed: onToggle);
    if (!extended) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMark) ...[mark, const SizedBox(height: 10)],
          toggle,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'OpenReader',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
            ),
          ),
          toggle,
        ],
      ),
    );
  }
}

/// The [<] / [>] button: a tinted, rounded button that brightens and grows a little under the
/// pointer, with a chevron that turns half a circle as the sidebar opens and closes.
class _SidebarToggle extends StatefulWidget {
  final bool extended;
  final VoidCallback onPressed;

  const _SidebarToggle({required this.extended, required this.onPressed});

  @override
  State<_SidebarToggle> createState() => _SidebarToggleState();
}

class _SidebarToggleState extends State<_SidebarToggle> {
  static const _duration = Duration(milliseconds: 220);
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final shortcut = PlatformInfo.isMacOS ? '⌘B' : 'Ctrl+B';
    return Tooltip(
      message: widget.extended
          ? 'Collapse sidebar ($shortcut)'
          : 'Expand sidebar ($shortcut)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          button: true,
          label: widget.extended ? 'Collapse sidebar' : 'Expand sidebar',
          child: GestureDetector(
            onTap: widget.onPressed,
            child: AnimatedScale(
              scale: _hover ? 1.08 : 1,
              duration: _duration,
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: _duration,
                curve: Curves.easeOut,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _hover
                      ? context.secondaryContainer
                      : context.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: _hover
                          ? context.secondary.withValues(alpha: 0.35)
                          : Colors.transparent),
                ),
                // chevron_left is "collapse"; half a turn makes it "expand".
                child: AnimatedRotation(
                  turns: widget.extended ? 0 : 0.5,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOutCubic,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 22,
                    color:
                        _hover ? context.secondary : context.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  /// A small count shown at the end of the row (and on the icon when collapsed).
  final String? badge;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.badge,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.selected ? context.secondary : context.onSurfaceVariant;
    final background = widget.selected
        ? context.secondaryContainer
        : (_hover ? context.surfaceContainerLow : Colors.transparent);
    final icon = Icon(widget.selected ? widget.activeIcon : widget.icon,
        color: color, size: 22, semanticLabel: '');
    final content = widget.extended
        ? Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: context.bodyMedium?.copyWith(
                    color:
                        widget.selected ? context.secondary : context.onSurface,
                    fontWeight:
                        widget.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.selected
                        ? context.secondary
                        : context.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.badge!,
                    style: context.labelSmall?.copyWith(
                      color: widget.selected
                          ? Colors.white
                          : context.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          )
        : Center(
            child: widget.badge == null
                ? icon
                : Badge(label: Text(widget.badge!), child: icon),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        label: widget.label,
        selected: widget.selected,
        button: true,
        child: Tooltip(
          message: widget.extended ? '' : widget.label,
          child: MouseRegion(
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Material(
              color: background,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 46,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: widget.extended ? 14 : 0),
                          child: content),
                      if (widget.selected)
                        Positioned(
                          left: 0,
                          child: Container(
                            width: 3,
                            height: 20,
                            decoration: BoxDecoration(
                              color: context.secondary,
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(3)),
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
      ),
    );
  }
}
