import 'package:flutter/material.dart';

enum DocumentCategory {
  pdf,
  word,
  excel,
  powerpoint,
  text,
  csv,
  unknown;

  static const Map<String, DocumentCategory> _byExtension = {
    'pdf': DocumentCategory.pdf,
    'doc': DocumentCategory.word,
    'docx': DocumentCategory.word,
    'xls': DocumentCategory.excel,
    'xlsx': DocumentCategory.excel,
    'ppt': DocumentCategory.powerpoint,
    'pptx': DocumentCategory.powerpoint,
    'txt': DocumentCategory.text,
    'csv': DocumentCategory.csv,
  };

  static DocumentCategory fromExtension(String extension) {
    return _byExtension[extension.toLowerCase()] ?? DocumentCategory.unknown;
  }

  static List<String> get supportedExtensions => _byExtension.keys.toList();

  String get label {
    switch (this) {
      case DocumentCategory.pdf:
        return 'PDF';
      case DocumentCategory.word:
        return 'Word';
      case DocumentCategory.excel:
        return 'Excel';
      case DocumentCategory.powerpoint:
        return 'PowerPoint';
      case DocumentCategory.text:
        return 'Text';
      case DocumentCategory.csv:
        return 'CSV';
      case DocumentCategory.unknown:
        return 'Unknown';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentCategory.pdf:
        return Icons.picture_as_pdf_outlined;
      case DocumentCategory.word:
        return Icons.description_outlined;
      case DocumentCategory.excel:
        return Icons.grid_on_outlined;
      case DocumentCategory.powerpoint:
        return Icons.slideshow_outlined;
      case DocumentCategory.text:
        return Icons.article_outlined;
      case DocumentCategory.csv:
        return Icons.table_chart_outlined;
      case DocumentCategory.unknown:
        return Icons.insert_drive_file_outlined;
    }
  }

  static DocumentCategory fromName(String value) {
    return DocumentCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => DocumentCategory.unknown,
    );
  }
}
