import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/presentation/theme/theme_extensions.dart';
import '../../core/presentation/utils/platform_info.dart';
import '../../core/presentation/utils/screen_utils.dart';
import '../../res/routes/app_routes.dart';
import 'app_shell_controller.dart';

/// The shell's destinations, shared by the phone bottom bar and the sidebar.
const shellDestinations = [
  (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
  (icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Browse'),
  (icon: Icons.star_outline_rounded, activeIcon: Icons.star_rounded, label: 'Library'),
];

/// Desktop / tablet sidebar: brand, primary "Open file" action, destinations
/// and Settings pinned to the bottom. Collapses to an icon rail on narrower
/// windows.
class DesktopSidebar extends StatelessWidget {
  final AppShellController controller;
  final bool extended;

  const DesktopSidebar({super.key, required this.controller, required this.extended});

  @override
  Widget build(BuildContext context) {
    final shortcut = PlatformInfo.isMacOS ? '⌘O' : 'Ctrl+O';
    // A phone on its side is short: drop the brand and tighten the spacing.
    final short = context.isShortScreen;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: extended ? 252 : 76,
      color: context.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(horizontal: extended ? 14 : 10, vertical: short ? 8 : 16),
      // Scrolls if even the compact rail does not fit (a very short window).
      child: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!short || extended) ...[_SidebarBrand(extended: extended), SizedBox(height: short ? 12 : 20)],
          if (extended)
            FilledButton(
              onPressed: controller.pickAndOpenFile,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.file_open_outlined, size: 20),
                  const SizedBox(width: 10),
                  const Text('Open file'),
                  const Spacer(),
                  Text(shortcut, style: context.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.75))),
                ],
              ),
            )
          else
            Tooltip(
              message: 'Open file ($shortcut)',
              child: FilledButton(
                onPressed: controller.pickAndOpenFile,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.file_open_outlined, size: 22),
              ),
            ),
          SizedBox(height: short ? 12 : 24),
          if (extended)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text('BROWSE', style: context.labelSmall?.copyWith(color: context.onSurfaceVariant, letterSpacing: 1.2)),
            ),
          Obx(() => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < shellDestinations.length; i++)
                    _SidebarItem(
                      icon: shellDestinations[i].icon,
                      activeIcon: shellDestinations[i].activeIcon,
                      label: shellDestinations[i].label,
                      selected: controller.currentIndex.value == i,
                      extended: extended,
                      onTap: () => controller.changeTab(i),
                    ),
                ],
              )),
          const Spacer(),
          Divider(height: short ? 12 : 24, color: context.outlineVariant),
          _SidebarItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Settings',
            selected: false,
            extended: extended,
            onTap: () => Get.toNamed(AppRoutes.settings),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  final bool extended;
  const _SidebarBrand({required this.extended});

  @override
  Widget build(BuildContext context) {
    final mark = ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: Image.asset('assets/icon/icon.png', width: 34, height: 34, filterQuality: FilterQuality.medium),
    );
    if (!extended) return Center(child: mark);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 12),
          Text('OpenReader', style: context.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2)),
        ],
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

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected ? context.secondary : context.onSurfaceVariant;
    final background = widget.selected
        ? context.secondaryContainer
        : (_hover ? context.surfaceContainerLow : Colors.transparent);
    final icon = Icon(widget.selected ? widget.activeIcon : widget.icon, color: color, size: 22, semanticLabel: '');
    final content = widget.extended
        ? Row(
            children: [
              icon,
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.label,
                  style: context.bodyMedium?.copyWith(
                    color: widget.selected ? context.secondary : context.onSurface,
                    fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          )
        : Center(child: icon);

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
                      Padding(padding: EdgeInsets.symmetric(horizontal: widget.extended ? 14 : 0), child: content),
                      if (widget.selected)
                        Positioned(
                          left: 0,
                          child: Container(
                            width: 3,
                            height: 20,
                            decoration: BoxDecoration(
                              color: context.secondary,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
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
