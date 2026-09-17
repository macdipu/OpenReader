import 'package:equatable/equatable.dart';

import 'document_category.dart';

class DocumentModel extends Equatable {
  final String id;
  final String path;
  final String displayName;
  final String extension;
  final DocumentCategory category;
  final int sizeBytes;
  final DateTime modifiedAt;
  final DateTime lastSeenAt;

  const DocumentModel({
    required this.id,
    required this.path,
    required this.displayName,
    required this.extension,
    required this.category,
    required this.sizeBytes,
    required this.modifiedAt,
    required this.lastSeenAt,
  });

  DocumentModel copyWith({
    DateTime? lastSeenAt,
    bool? exists,
  }) {
    return DocumentModel(
      id: id,
      path: path,
      displayName: displayName,
      extension: extension,
      category: category,
      sizeBytes: sizeBytes,
      modifiedAt: modifiedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'path': path,
        'display_name': displayName,
        'extension': extension,
        'category': category.name,
        'size_bytes': sizeBytes,
        'modified_at': modifiedAt.millisecondsSinceEpoch,
        'last_seen_at': lastSeenAt.millisecondsSinceEpoch,
      };

  factory DocumentModel.fromMap(Map<String, Object?> map) {
    return DocumentModel(
      id: map['id'] as String,
      path: map['path'] as String,
      displayName: map['display_name'] as String,
      extension: map['extension'] as String,
      category: DocumentCategory.fromName(map['category'] as String),
      sizeBytes: map['size_bytes'] as int,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(map['modified_at'] as int),
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(map['last_seen_at'] as int),
    );
  }

  @override
  List<Object?> get props => [id, path, displayName, extension, category, sizeBytes, modifiedAt, lastSeenAt];
}

enum DocumentSortMode {
  nameAsc,
  nameDesc,
  newestFirst,
  oldestFirst,
  largestFirst,
  smallestFirst,
}

extension DocumentSortModeLabel on DocumentSortMode {
  String get label {
    switch (this) {
      case DocumentSortMode.nameAsc:
        return 'Name A–Z';
      case DocumentSortMode.nameDesc:
        return 'Name Z–A';
      case DocumentSortMode.newestFirst:
        return 'Newest modified first';
      case DocumentSortMode.oldestFirst:
        return 'Oldest modified first';
      case DocumentSortMode.largestFirst:
        return 'Largest file first';
      case DocumentSortMode.smallestFirst:
        return 'Smallest file first';
    }
  }
}
