/// High-level codec facade for CSV encoding and decoding.
///
/// [CsvCodec] is the main entry point for most users:
///
/// ```dart
/// final codec = CsvCodec();
/// final rows  = codec.decode('a,b\n1,2');
/// final csv   = codec.encode([['a','b'], [1, 2]]);
/// ```
///
/// Convenience constants [csvPlus], [csvExcel], and [csvTsv] provide
/// pre-configured codec instances.
///
/// [CsvCodecAdapter] integrates with the `dart:convert` [Codec] API for
/// pipeline composition with other converters.
library;

export 'src/codec/csv_codec.dart';
export 'src/codec/codec_adapter.dart';
