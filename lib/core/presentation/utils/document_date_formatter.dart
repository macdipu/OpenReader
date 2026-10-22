import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// The one absolute date format for documents (CR-OPENREADER-UX UX-25):
/// locale-aware medium date, e.g. "Oct 22, 2026" in English. Replaces the
/// mix of DD/MM/YYYY and ISO dates screens used before. Falls back to English
/// if the app locale has no date data loaded.
String formatDocumentDate(DateTime time) {
  final local = time.toLocal();
  final locale = Get.locale?.languageCode;
  try {
    return DateFormat.yMMMd(locale).format(local);
  } catch (_) {
    return DateFormat.yMMMd('en').format(local);
  }
}
