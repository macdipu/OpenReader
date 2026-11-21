import '../../../services/utilities/storage_access_service.dart';

/// A run of step text; [bold] marks the words the user must look for on screen.
class HelpSpan {
  final String text;
  final bool bold;
  const HelpSpan(this.text, {this.bold = false});
}

/// The by-hand steps for giving file access, for one phone brand family and Android version. Pure
/// data: the sheet in Settings and the onboarding denied states both render it.
class StorageAccessHelp {
  static const title = 'Allow file access';
  static const purpose =
      'OpenReader needs "All files access" to find your documents. Your files stay on this phone.';
  static const manualLabel = 'Or find it yourself';
  static const openPageLabel = 'Open All files access';
  static const openAppSettingsLabel = 'Open app settings';

  /// Android 10 and older (API 29): the plain runtime Storage permission, no brand-specific page.
  static const legacyMaxSdk = 29;

  /// The one switch label the user must choose (also quoted by the "still off" snackbar).
  final String switchLabel;

  /// Numbered steps, each a list of spans.
  final List<List<HelpSpan>> steps;

  /// The brand's path to the page by hand; null on Android 10 and older.
  final String? manualPath;

  /// True on Android 10 and older.
  final bool legacy;

  const StorageAccessHelp._({
    required this.switchLabel,
    required this.steps,
    required this.manualPath,
    required this.legacy,
  });

  static const _stockSwitch = 'Allow access to manage all files';

  static const _switchLabels = {
    DeviceBrand.samsung: 'Allow permission',
    DeviceBrand.coloros: 'Allow management of all files',
    DeviceBrand.hyperos: _stockSwitch,
    DeviceBrand.vivo: _stockSwitch,
    DeviceBrand.other: _stockSwitch,
  };

  static const _manualPaths = {
    DeviceBrand.samsung:
        'Settings > Apps > Special access > All files access > OpenReader',
    DeviceBrand.coloros:
        'Settings > Apps > App management > OpenReader > Permissions > Files and media',
    DeviceBrand.hyperos:
        'Settings > Apps > Manage apps > OpenReader > Permissions',
    DeviceBrand.vivo:
        'Settings > Apps & permissions > Permission management > OpenReader',
    DeviceBrand.other:
        'Settings > Apps > Special app access > All files access > OpenReader',
  };

  /// The switch label for [brand] (stock wording for [DeviceBrand.other]).
  static String switchLabelFor(DeviceBrand brand) =>
      _switchLabels[brand] ?? _stockSwitch;

  /// The help for [brand] on Android [sdk]. An unknown [sdk] counts as Android 11 or newer. Step 1 names
  /// the button on screen that opens the page, [primaryLabel].
  factory StorageAccessHelp.forDevice({
    required DeviceBrand brand,
    int? sdk,
    String primaryLabel = openPageLabel,
  }) {
    if (sdk != null && sdk <= legacyMaxSdk) {
      return const StorageAccessHelp._(
        switchLabel: 'Allow',
        steps: [
          [
            HelpSpan('Tap '),
            HelpSpan('Allow', bold: true),
            HelpSpan(' on the Storage permission prompt.')
          ],
        ],
        manualPath: null,
        legacy: true,
      );
    }
    final label = switchLabelFor(brand);
    return StorageAccessHelp._(
      switchLabel: label,
      steps: [
        [
          const HelpSpan('Tap '),
          HelpSpan(primaryLabel, bold: true),
          const HelpSpan(' below.')
        ],
        [
          HelpSpan(brand == DeviceBrand.coloros ? 'Choose ' : 'Turn on '),
          HelpSpan(label, bold: true),
          const HelpSpan('.'),
        ],
        const [HelpSpan('Come back to OpenReader.')],
      ],
      manualPath: _manualPaths[brand],
      legacy: false,
    );
  }
}

/// Reads the brand and Android version from [access] and builds the help. Never throws: anything
/// unreadable gives the stock Android steps.
Future<StorageAccessHelp> loadStorageAccessHelp(StorageAccessService access,
    {String primaryLabel = StorageAccessHelp.openPageLabel}) async {
  var brand = DeviceBrand.other;
  int? sdk;
  try {
    sdk = await access.androidSdkInt();
  } catch (_) {}
  try {
    brand = await access.deviceBrand();
  } catch (_) {}
  return StorageAccessHelp.forDevice(
      brand: brand, sdk: sdk, primaryLabel: primaryLabel);
}
