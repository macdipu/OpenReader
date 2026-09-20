import '../../domain/extensions/extension_export.dart';

/// Formats a timestamp as "Just now" / "Xm ago" / "Xh ago" / "Xd ago",
/// falling back to a plain date past a week (Home "Continue Reading" /
/// Favorites & History rows).
String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return time.toDMYString();
}
