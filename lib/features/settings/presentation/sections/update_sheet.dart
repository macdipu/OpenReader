import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/presentation/theme/theme_extensions.dart';
import '../../../../services/utilities/update_checker.dart';

/// Settings > About > Version: what the store and GitHub have, in one sheet.
///
/// The official store comes first, with its version: Google Play on Android, the App Store on iOS. GitHub
/// never replaces it. Only when GitHub has a build strictly newer than the store's does a second card appear,
/// "Early Build Available", with a button to download it before the store has it. On desktop there is no
/// store: GitHub is the release to update to.
class UpdateSheet extends StatelessWidget {
  const UpdateSheet({super.key, required this.check, required this.actions});

  /// The answer being fetched.
  final Future<UpdateCheck> check;

  /// What the buttons do.
  final UpdateActions actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        decoration: BoxDecoration(color: context.surfaceContainerLow, borderRadius: BorderRadius.circular(28)),
        child: SingleChildScrollView(
          child: FutureBuilder<UpdateCheck>(
            future: check,
            builder: (context, snapshot) {
              final result = snapshot.data;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(color: context.outlineVariant, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Header(installed: result?.installed),
                  const SizedBox(height: 18),
                  if (snapshot.hasError)
                    const _Message(icon: Icons.cloud_off_rounded, text: 'Could not check for updates right now.')
                  else if (result == null)
                    const _Checking()
                  else
                    ..._cards(context, result),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _cards(BuildContext context, UpdateCheck result) {
    if (result.failed) {
      return const [_Message(icon: Icons.cloud_off_rounded, text: 'Could not check for updates. Check your connection and try again.')];
    }
    final offer = result.offer;
    final github = offer.github;
    final cards = <Widget>[];

    if (result.platform == UpdatePlatform.desktop || offer.githubIsMainSource) {
      // No store to ask: GitHub is the release to update to.
      cards.add(
        _SourceCard(
          key: const Key('update-github-main'),
          icon: Icons.system_update_alt_rounded,
          source: 'GitHub',
          version: github == null ? 'v${result.installed}' : github.tag,
          caption: github == null ? 'You have the latest version.' : 'A newer version is available.',
          upToDate: github == null,
          button: github == null
              ? null
              : _Action(
                  label: result.platform == UpdatePlatform.desktop ? 'Download and install' : 'Download update',
                  icon: Icons.download_rounded,
                  onPressed: () => result.platform == UpdatePlatform.desktop ? actions.installFromGitHub(result) : actions.downloadEarlyBuild(result),
                ),
        ),
      );
      // Say why it is GitHub and not the store: this build did not come from Google Play (or Play was not reachable).
      if (result.platform == UpdatePlatform.android && result.storeUnreachable) {
        cards
          ..add(const SizedBox(height: 12))
          ..add(const _Message(key: Key('update-store-unreachable'), icon: Icons.info_outline_rounded, text: 'Could not reach Google Play, so this is the latest release on GitHub.'));
      }
      return cards;
    }

    // The store, always first, with its version.
    final name = result.storeName ?? 'The store';
    if (result.storeUnreachable) {
      cards.add(_Message(key: const Key('update-store-unreachable'), icon: Icons.cloud_off_rounded, text: 'Could not reach $name.'));
    } else {
      cards.add(
        _SourceCard(
          key: const Key('update-store'),
          icon: result.platform == UpdatePlatform.ios ? Icons.apple : Icons.shop_rounded,
          source: name,
          version: result.storeVersionLabel ?? 'v${result.installed}',
          caption: offer.storeUpdate ? 'A newer version is available.' : 'You have the latest version.',
          upToDate: !offer.storeUpdate,
          button: offer.storeUpdate
              ? _Action(
                  label: result.platform == UpdatePlatform.ios ? 'Open App Store' : 'Update on $name',
                  icon: Icons.system_update_rounded,
                  primary: true,
                  onPressed: () => result.platform == UpdatePlatform.ios ? actions.openStore(result) : actions.startStoreUpdate(result),
                )
              : null,
        ),
      );
    }

    // A second option, only when GitHub is strictly newer than the store.
    if (github != null) {
      cards
        ..add(const SizedBox(height: 12))
        ..add(
          _EarlyBuildCard(
            key: const Key('update-early-build'),
            version: github.tag,
            storeName: name,
            onDownload: () => actions.downloadEarlyBuild(result),
          ),
        );
    }
    return cards;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.installed});

  final String? installed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: context.primaryContainer, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.system_update_rounded, color: context.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Updates', style: context.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                installed == null ? 'Checking…' : 'Installed: v$installed',
                style: context.bodySmall?.copyWith(color: context.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('update-checking'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 12),
          Flexible(child: Text('Checking for updates…', style: context.bodyMedium)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.outlineVariant)),
      child: Row(
        children: [
          Icon(icon, color: context.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: context.bodyMedium)),
        ],
      ),
    );
  }
}

class _Action {
  const _Action({required this.label, required this.icon, required this.onPressed, this.primary = false});

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
}

/// A source of updates (the store, or GitHub where there is none): its name, the version it has, and what to
/// do about it.
class _SourceCard extends StatelessWidget {
  const _SourceCard({
    super.key,
    required this.icon,
    required this.source,
    required this.version,
    required this.caption,
    required this.upToDate,
    this.button,
  });

  final IconData icon;
  final String source;
  final String version;
  final String caption;
  final bool upToDate;
  final _Action? button;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: context.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(source, style: context.labelLarge?.copyWith(color: context.onSurfaceVariant))),
              _Chip(label: upToDate ? 'Up to date' : 'Update available', good: upToDate),
            ],
          ),
          const SizedBox(height: 10),
          Text(version, style: context.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(caption, style: context.bodySmall?.copyWith(color: context.onSurfaceVariant)),
          if (button != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: button!.onPressed,
              icon: Icon(button!.icon),
              label: Text(button!.label),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Early Build Available": GitHub has a newer version than the store. A second option below the store's.
class _EarlyBuildCard extends StatelessWidget {
  const _EarlyBuildCard({super.key, required this.version, required this.storeName, required this.onDownload});

  final String version;
  final String storeName;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.tertiary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 20, color: context.onTertiaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Early Build Available',
                  style: context.labelLarge?.copyWith(color: context.onTertiaryContainer, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(version, style: context.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: context.onTertiaryContainer)),
          const SizedBox(height: 2),
          Text(
            'GitHub has a newer version than $storeName. You can try it before it reaches the store.',
            style: context.bodySmall?.copyWith(color: context.onTertiaryContainer),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: context.onTertiaryContainer),
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded),
            label: const Text('Download Early Build'),
          ),
          const SizedBox(height: 8),
          Text(
            'An early build can be less tested. If Android refuses to install it over the $storeName version, '
            'wait for the store.',
            style: context.bodySmall?.copyWith(color: context.onTertiaryContainer.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.good});

  final String label;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final color = good ? context.success : context.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: context.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

/// Opens [UpdateSheet].
Future<void> showUpdateSheet({required Future<UpdateCheck> check, required UpdateActions actions}) =>
    Get.bottomSheet<void>(UpdateSheet(check: check, actions: actions), isScrollControlled: true, backgroundColor: Colors.transparent);
