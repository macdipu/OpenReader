import 'package:flutter/material.dart';

import '../../presentation/theme/color_schemes.dart';

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

  /// 3-4 letter badge code shown on the format tile (BRD 9.4 / DESIGN_SPEC
  /// "Format badge").
  String get shortCode {
    switch (this) {
      case DocumentCategory.pdf:
        return 'PDF';
      case DocumentCategory.word:
        return 'DOC';
      case DocumentCategory.excel:
        return 'XLS';
      case DocumentCategory.powerpoint:
        return 'PPT';
      case DocumentCategory.text:
        return 'TXT';
      case DocumentCategory.csv:
        return 'CSV';
      case DocumentCategory.unknown:
        return 'FILE';
    }
  }

  /// Format accent color (badge text/border, progress fill, highlights) -
  /// see DESIGN_SPEC.md "Format accent colors". Nocturne (dark) reuses the
  /// light cyan/teal for TXT/CSV since the dark system doesn't define one.
  AdaptiveColor get accentColor {
    switch (this) {
      case DocumentCategory.pdf:
        return const AdaptiveColor(light: Color(0xFFDC2626), dark: Color(0xFF38BDF8));
      case DocumentCategory.word:
        return const AdaptiveColor(light: Color(0xFF2563EB), dark: Color(0xFF818CF8));
      case DocumentCategory.excel:
        return const AdaptiveColor(light: Color(0xFF059669), dark: Color(0xFF4EE6AA));
      case DocumentCategory.powerpoint:
        return const AdaptiveColor(light: Color(0xFFD97706), dark: Color(0xFFFB923C));
      case DocumentCategory.text:
      case DocumentCategory.csv:
        return const AdaptiveColor(light: Color(0xFF0891B2), dark: Color(0xFF67E8F9));
      case DocumentCategory.unknown:
        return const AdaptiveColor(light: Color(0xFF64748B), dark: Color(0xFF94A3B8));
    }
  }

  /// Tint background behind the format badge (10-15% wash of [accentColor]).
  AdaptiveColor get tintColor {
    switch (this) {
      case DocumentCategory.pdf:
        return const AdaptiveColor(light: Color(0xFFFEF2F2), dark: Color(0x2638BDF8));
      case DocumentCategory.word:
        return const AdaptiveColor(light: Color(0xFFEFF6FF), dark: Color(0x26818CF8));
      case DocumentCategory.excel:
        return const AdaptiveColor(light: Color(0xFFECFDF5), dark: Color(0x264EE6AA));
      case DocumentCategory.powerpoint:
        return const AdaptiveColor(light: Color(0xFFFFFBEB), dark: Color(0x26FB923C));
      case DocumentCategory.text:
      case DocumentCategory.csv:
        return const AdaptiveColor(light: Color(0xFFECFEFF), dark: Color(0x2667E8F9));
      case DocumentCategory.unknown:
        return const AdaptiveColor(light: Color(0xFFF1F5F9), dark: Color(0x2694A3B8));
    }
  }

  static DocumentCategory fromName(String value) {
    return DocumentCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => DocumentCategory.unknown,
    );
  }
}
