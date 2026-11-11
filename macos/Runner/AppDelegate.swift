import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

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
        guard let self = self else {
          result(FlutterMethodNotImplemented)
          return
        }
        switch call.method {
        case "takeInitialFiles":
          self.dartReady = true
          let files = self.pendingFiles
          self.pendingFiles = []
          result(files)
        case "setDefaultForExtensions":
          self.setDefault(forExtensions: call.arguments as? [String] ?? [], result: result)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      self.channel = channel
    }
    super.applicationDidFinishLaunching(notification)
  }

  /// Makes OpenReader the default app for each extension; replies with the extensions that failed.
  /// macOS shows its own confirmation, so a refusal by the user also lands in the failed list.
  private func setDefault(forExtensions extensions: [String], result: @escaping FlutterResult) {
    let appURL = Bundle.main.bundleURL
    Task {
      var failed: [String] = []
      for ext in extensions {
        guard let type = UTType(filenameExtension: ext) else {
          failed.append(ext)
          continue
        }
        do {
          try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type)
        } catch {
          failed.append(ext)
        }
      }
      result(failed)
    }
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
