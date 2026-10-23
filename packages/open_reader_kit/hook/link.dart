import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const _pdfiumAssetId = 'package:open_reader_kit/libpdfium';

/// Drops the downloaded PDFium on iOS, where the plugin's xcframework
/// (darwin/) already links it into the app. macOS keeps it: the
/// xcframework links it there too, but `flutter test` on a Mac loads the
/// asset directly.
///
/// Upstream this was two hooks (pdfium_flutter told pdfium_dart through
/// link metadata); in one package the plugin is always present.
void main(List<String> args) async {
  await link(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      output.assets.addEncodedAssets(input.assets.encodedAssets);
      return;
    }
    final omitPdfium = input.config.code.targetOS == OS.iOS;
    for (final asset in input.assets.encodedAssets) {
      final isPdfium = asset.isCodeAsset && CodeAsset.fromEncoded(asset).id == _pdfiumAssetId;
      if (omitPdfium && isPdfium) continue;
      output.assets.addEncodedAsset(asset);
    }
  });
}
