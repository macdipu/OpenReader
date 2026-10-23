#if os(iOS)
  import Flutter
#elseif os(macOS)
  import FlutterMacOS
#endif

public class OpenReaderKitPlugin: NSObject, FlutterPlugin {
  public static func register(with _: FlutterPluginRegistrar) {
    // This is an FFI plugin - no platform channel needed
    // The native code is accessed via FFI from open_reader_kit
  }

  func dummyMethodToPreventStripping() {
    // This method prevents the linker from stripping the PDFium framework
  }
}
