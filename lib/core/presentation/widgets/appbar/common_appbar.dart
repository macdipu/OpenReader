import 'package:flutter/material.dart';
import 'package:get/get.dart';

class CommonAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final List<Widget>? actions;

  CommonAppbar({
    super.key,
    this.title,
    this.leading,
    this.bottom,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return AppBar(

      leading: leading ??
          (canPop
              ? GestureDetector(
                  onTap: () {
                    Get.back();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.arrow_back,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                )
              : null),
      actions: actions,
      bottom: bottom,
      centerTitle: false,
      title: Text(
        title ?? '',
        style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface),
      ),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      scrolledUnderElevation: 0,
      bottomOpacity: 1,
    );
  }

  @override
  Size get preferredSize => Size(
    double.infinity,
    kToolbarHeight + (bottom?.preferredSize.height ?? 0),
  );
}
