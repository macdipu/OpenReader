import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/presentation/theme/theme_extensions.dart';
import '../../core/presentation/utils/screen_utils.dart';
import '../../res/routes/app_routes.dart';
import '../../features/favorites/presentation/favorites_view.dart';
import '../../features/files/presentation/files_view.dart';
import '../../features/home/presentation/home_view.dart';
import 'app_shell_controller.dart';

/// Adaptive shell: Home / Files / Favorites (BRD 9.3). Phones get the bottom
/// navigation bar; wider windows (tablets, desktop) get a side navigation rail
/// with Open file / Rescan / Settings actions, and the page content is capped
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
    final wide = !context.isCompactScreen;

    final pages = Obx(() => IndexedStack(
          index: controller.currentIndex.value,
          children: const [
            HomeView(),
            FilesView(),
            FavoritesView(),
          ],
        ));

    return Scaffold(
      body: wide
          ? Row(
              children: [
                _AppNavRail(controller: controller, extended: context.isExpandedScreen),
                VerticalDivider(width: 1, color: context.outlineVariant),
                Expanded(child: ContentConstraint(child: pages)),
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
  }
}

class _AppNavRail extends StatelessWidget {
  final AppShellController controller;
  final bool extended;

  const _AppNavRail({required this.controller, required this.extended});

  @override
  Widget build(BuildContext context) {
    return Obx(() => NavigationRail(
          extended: extended,
          backgroundColor: context.surfaceContainerLowest,
          selectedIndex: controller.currentIndex.value,
          onDestinationSelected: controller.changeTab,
          labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
          indicatorColor: context.secondaryContainer,
          leading: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: extended
                ? FilledButton.icon(
                    onPressed: controller.pickAndOpenFile,
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Open file'),
                  )
                : IconButton.filledTonal(
                    tooltip: 'Open file',
                    onPressed: controller.pickAndOpenFile,
                    icon: const Icon(Icons.file_open_outlined),
                  ),
          ),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Rescan storage',
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: controller.rescan,
                    ),
                    IconButton(
                      tooltip: 'Settings',
                      icon: const Icon(Icons.settings_outlined),
                      onPressed: () => Get.toNamed(AppRoutes.settings),
                    ),
                  ],
                ),
              ),
            ),
          ),
          destinations: [
            for (final item in _AppNavBar._items)
              NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon),
                label: Text(item.label),
              ),
          ],
        ));
  }
}

class _AppNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _AppNavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.folder_outlined, activeIcon: Icons.folder_rounded, label: 'Files'),
    (icon: Icons.star_outline_rounded, activeIcon: Icons.star_rounded, label: 'Library'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surfaceContainerLowest,
        border: Border(top: BorderSide(color: context.outlineVariant)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
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
