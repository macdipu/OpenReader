import 'package:equatable/equatable.dart';

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

  @override
  List<Object?> get props => [document, lastOpenedAt, readingPosition];
}
