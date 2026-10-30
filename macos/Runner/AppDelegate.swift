import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Finder ("Open With", double-click, drop on the Dock icon) delivers files as
  // an Apple Event, not argv. They are queued until Dart asks for them, then
  // pushed straight through while the app is running.
  private var channel: FlutterMethodChannel?
  private var pendingFiles: [String] = []
  private var dartReady = false

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "openreader/open_files", binaryMessenger: controller.engine.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self, call.method == "takeInitialFiles" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self.dartReady = true
        let files = self.pendingFiles
        self.pendingFiles = []
        result(files)
      }
      self.channel = channel
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    if dartReady {
      channel?.invokeMethod("openFiles", arguments: filenames)
    } else {
      pendingFiles.append(contentsOf: filenames)
    }
    sender.reply(toOpenOrPrint: .success)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
