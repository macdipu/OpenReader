import 'package:path/path.dart' as p;

import '../../../core/domain/models/recent_document_model.dart';
import '../../../core/presentation/utils/document_date_formatter.dart';
import '../../../core/presentation/utils/file_size_formatter.dart';

/// Desktop Home's wording for times, positions and places.

/// "Just now", "5 minutes ago", "Yesterday", "2 days ago"; a plain date past a week.
String formatRelativeTimeLong(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  String plural(int n, String unit) => '$n $unit${n == 1 ? '' : 's'} ago';
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return plural(diff.inMinutes, 'minute');
  if (diff.inHours < 24) return plural(diff.inHours, 'hour');
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return plural(diff.inDays, 'day');
  return formatDocumentDate(time);
}

/// Where reading resumes, from the reader's saved position: "Page 12 of 40", "Slide 3",
/// "Sheet 2", "Line 120". Null when the position names none of these.
String? readingPositionLabel(RecentDocumentModel recent) {
  final position = recent.readingPosition;
  int? read(String key) => switch (position[key]) { final int value => value, _ => null };
  String ofCount(String unit, int number, int? count) =>
      count != null && count >= number ? '$unit $number of $count' : '$unit $number';

  if (read('page_number') case final int page when page > 0) return ofCount('Page', page, read('page_count'));
  if (read('slide_index') case final int slide when slide >= 0) {
    return ofCount('Slide', slide + 1, read('slide_count'));
  }
  if (read('sheet_index') case final int sheet when sheet >= 0) {
    final row = read('row');
    return row != null && row > 0 ? 'Sheet ${sheet + 1}, row ${row + 1}' : 'Sheet ${sheet + 1}';
  }
  if (read('line') case final int line when line > 0) return 'Line ${line + 1}';
  return null;
}

/// "Excel · 5.8 KB".
String formatAndSize(RecentDocumentModel recent) =>
    '${recent.document.formatLabel} · ${formatFileSize(recent.document.sizeBytes)}';

/// The name of the folder holding [path] ("samples"), not the full path.
String folderName(String path) {
  final folder = p.basename(p.dirname(path));
  return folder.isEmpty ? p.dirname(path) : folder;
}
