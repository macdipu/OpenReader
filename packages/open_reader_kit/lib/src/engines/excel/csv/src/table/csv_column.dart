/// Describes a column in a [CsvTable].
class CsvColumn {
  /// Column header name.
  final String name;

  /// Column index (0-based).
  final int index;

  /// All values in this column.
  final List<dynamic> values;

  /// Create a column descriptor from [name], [index], and [values].
  CsvColumn({required this.name, required this.index, required this.values});

  /// Inferred type of this column based on non-null values.
  Type get inferredType {
    Type? common;
    for (final v in values) {
      if (v == null) continue;
      final t = v.runtimeType;
      if (common == null) {
        common = t;
      } else if (common != t) {
        return dynamic;
      }
    }
    return common ?? dynamic;
  }

  /// Count of non-null values.
  int get nonNullCount => values.where((v) => v != null).length;

  /// Count of null values.
  int get nullCount => values.where((v) => v == null).length;

  /// Count of unique values (including null).
  int get uniqueCount => values.toSet().length;
}
