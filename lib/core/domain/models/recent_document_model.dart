import 'package:equatable/equatable.dart';

import 'document_category.dart';
import 'document_model.dart';

/// A document paired with its reading-history metadata (BRD 7.5, 16).
class RecentDocumentModel extends Equatable {
  final DocumentModel document;
  final DateTime lastOpenedAt;

  /// Format-specific reading position, kept as opaque key/value pairs
  /// (page/zoom/scroll for PDF, sheet/row/column for Excel, slide index for
  /// PowerPoint) so this model doesn't need to change per reader type.
  final Map<String, Object?> readingPosition;

  const RecentDocumentModel({
    required this.document,
    required this.lastOpenedAt,
    this.readingPosition = const {},
  });

  /// 0-1 reading progress, or null when the format has no meaningful
  /// denominator. Only the PDF reader saves one (`page_count`, since
  /// CR-OPENREADER-UX UX-13); positions saved before that have none.
  double? get progress {
    if (document.category != DocumentCategory.pdf) return null;
    final page = readingPosition['page_number'];
    final count = readingPosition['page_count'];
    if (page is! int || count is! int || page < 1 || count < 1) return null;
    return (page / count).clamp(0, 1).toDouble();
  }

  @override
  List<Object?> get props => [document, lastOpenedAt, readingPosition];
}
