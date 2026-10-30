import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/presentation/theme/theme_extensions.dart';
import '../../core/presentation/utils/screen_utils.dart';
import '../../res/routes/app_routes.dart';
import '../../features/favorites/presentation/favorites_view.dart';
import '../../features/browse/presentation/browse_view.dart';
import '../../features/home/presentation/home_view.dart';
import 'app_shell_controller.dart';
import '../../core/presentation/widgets/fold_aware_sub_screen.dart';
import 'desktop_sidebar.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../core/presentation/utils/platform_info.dart';
import '../../core/presentation/widgets/app_shortcuts.dart';

/// Adaptive shell: Home / Files / Favorites (BRD 9.3). Phones get the bottom
/// navigation bar; wider windows (tablets, desktop) get a side navigation rail
/// with Open file / Settings actions, and the page content is capped
/// to a readable width. Settings is a pushed route (AppRoutes.settings), not a
/// tab - on phones it is reached via the gear icon in Home's app bar.
///
/// Bottom bar follows DESIGN_SPEC.md "BottomNavBar": 80dp, hairline top
/// border, active destination gets a pill-shaped highlight behind icon+label.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppShellController>();
    final wide = context.usesSideNav;

    final pages = Obx(() => IndexedStack(
          index: controller.currentIndex.value,
          children: const [
            HomeView(),
            BrowseView(),
            FavoritesView(),
          ],
        ));

    final scaffold = Scaffold(
      body: wide
          ? Row(
              children: [
                DesktopSidebar(controller: controller, extended: context.isExpandedScreen),
                VerticalDivider(width: 1, color: context.outlineVariant),
                // A hinge or fold splits the window: keep the pages on one side of it.
                Expanded(child: FoldAwareSubScreen(
                  // Home splits into list and details, so it gets more room than the lists.
                  child: Obx(() => ContentConstraint(
                    maxWidth: controller.currentIndex.value == AppShellController.homeIndex ? 1240 : ScreenUtils.maxContentWidth,
                    child: pages,
                  )),
                )),
              ],
            )
          : pages,
      bottomNavigationBar: wide
          ? null
          : Obx(() => _AppNavBar(
                currentIndex: controller.currentIndex.value,
                onTap: controller.changeTab,
              )),
    );

    final shell = AppShortcuts(
      onOpenFile: controller.pickAndOpenFile,
      onSearch: () => Get.toNamed(AppRoutes.search),
      child: scaffold,
    );
    if (!PlatformInfo.isDesktop) return shell;
    // Desktop: drop a file onto the window to open it (UX-34).
    return DropTarget(
      onDragEntered: (_) => controller.isDraggingFile.value = true,
      onDragExited: (_) => controller.isDraggingFile.value = false,
      onDragDone: (details) => controller.openDroppedPaths([for (final f in details.files) f.path]),
      child: Stack(
        children: [
          shell,
          Obx(() => controller.isDraggingFile.value ? const _DropOverlay() : const SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// Shown while a file is dragged over the window.
class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: context.scrim.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              color: context.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.secondary, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_open_outlined, color: context.secondary),
                const SizedBox(width: 12),
                Text('Drop to open', style: context.titleMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AppNavBar({required this.currentIndex, required this.onTap});

  static const _items = shellDestinations;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest,
        border: Border(top: BorderSide(color: context.outlineVariant)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: context.scaledExtent(64),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavItem(
                  icon: _items[i].icon,
                  activeIcon: _items[i].activeIcon,
                  label: _items[i].label,
                  selected: currentIndex == i,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.secondary : context.onSurfaceVariant;
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? context.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 22, semanticLabel: ''),
              if (selected) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: context.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
