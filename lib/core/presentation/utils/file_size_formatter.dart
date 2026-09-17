/// Formats a byte count for display in file lists (BRD 9.4 - File Row Information).
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final precision = value < 10 ? 1 : 0;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}
