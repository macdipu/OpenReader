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
  /// denominator. The PDF reader saves `page_count` (since CR-OPENREADER-UX
  /// UX-13; positions saved before that have none), the PowerPoint reader
  /// `slide_count` (CR-OPENREADER-PPTX).
  double? get progress {
    final (int? done, int? count) = switch (document.category) {
      DocumentCategory.pdf => (_int('page_number'), _int('page_count')),
      // Zero-based index; slide 1 of 10 has read one slide.
      DocumentCategory.powerpoint => (
          switch (_int('slide_index')) { final int i => i + 1, _ => null },
          _int('slide_count')
        ),
      _ => (null, null),
    };
    if (done == null || count == null || done < 1 || count < 1) return null;
    return (done / count).clamp(0, 1).toDouble();
  }

  int? _int(String key) => switch (readingPosition[key]) { final int value => value, _ => null };

  @override
  List<Object?> get props => [document, lastOpenedAt, readingPosition];
}
