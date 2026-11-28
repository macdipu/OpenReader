import Cocoa
import FlutterMacOS
import NaturalLanguage
import UniformTypeIdentifiers
import Vision

@main
class AppDelegate: FlutterAppDelegate {
  // Finder ("Open With", double-click, drop on the Dock icon) delivers files as
  // an Apple Event, not argv. They are queued until Dart asks for them, then
  // pushed straight through while the app is running.
  private var channel: FlutterMethodChannel?
  private var ocrChannel: FlutterMethodChannel?
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
        case "queryDefaultForExtensions":
          result(self.queryDefault(forExtensions: call.arguments as? [String] ?? []))
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      self.channel = channel

      // OCR for scanned PDF pages (CR-READER-SELECT-OCR SO-14).
      let ocr = FlutterMethodChannel(name: "openreader/ocr", binaryMessenger: controller.engine.binaryMessenger)
      ocr.setMethodCallHandler { call, result in
        guard call.method == "recognize", let args = call.arguments as? [String: Any],
          let png = args["png"] as? FlutterStandardTypedData
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        let languages = args["languages"] as? [String] ?? []
        DispatchQueue.global(qos: .userInitiated).async {
          do {
            let out = try VisionOcr.recognize(png: png.data, languages: languages)
            DispatchQueue.main.async { result(out) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "ocr_failed", message: "\(error)", details: nil))
            }
          }
        }
      }
      self.ocrChannel = ocr
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

  /// For each extension, whether this app is the one macOS opens it with. Extensions with an
  /// unknown type or no handler are left out so Dart reports them as unknown.
  private func queryDefault(forExtensions extensions: [String]) -> [String: Bool] {
    let me = Bundle.main.bundleURL.standardizedFileURL
    var out: [String: Bool] = [:]
    for ext in extensions {
      guard let type = UTType(filenameExtension: ext),
        let app = NSWorkspace.shared.urlForApplication(toOpen: type)
      else { continue }
      out[ext] = app.standardizedFileURL == me
    }
    return out
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    deliver(filenames)
    sender.reply(toOpenOrPrint: .success)
  }

  // FlutterAppDelegate implements this one (for deep links), and AppKit prefers it over
  // `openFiles`, so without this override Finder's double-click / Open With never reaches Dart.
  override func application(_ application: NSApplication, open urls: [URL]) {
    let files = urls.filter { $0.isFileURL }.map { $0.path }
    if !files.isEmpty { deliver(files) }
    let others = urls.filter { !$0.isFileURL }
    if !others.isEmpty { super.application(application, open: others) }
  }

  private func deliver(_ filenames: [String]) {
    if dartReady {
      channel?.invokeMethod("openFiles", arguments: filenames)
    } else {
      pendingFiles.append(contentsOf: filenames)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

// BEGIN VisionOcr (kept free of Flutter types so it can be compiled and tried on its own)

/// Text recognition through Apple Vision: on the device, no network. The
/// language is detected by Vision itself on macOS 13 and later; `languages`
/// (language codes the caller chose) override that.
enum VisionOcr {
  enum Failure: Error { case badImage }

  /// Reads the PNG in [png]. Returns `["lines": [[text, left, top, right, bottom, confidence]],
  /// "language": String?]` with boxes in image pixels from the top-left.
  static func recognize(png: Data, languages: [String]) throws -> [String: Any] {
    guard let source = CGImageSourceCreateWithData(png as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw Failure.badImage }
    let width = Double(image.width)
    let height = Double(image.height)

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    if !languages.isEmpty {
      request.recognitionLanguages = languages
    } else if #available(macOS 13.0, *) {
      request.automaticallyDetectsLanguage = true
    }
    try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

    var lines: [[String: Any]] = []
    var all: [String] = []
    for observation in request.results ?? [] {
      guard let best = observation.topCandidates(1).first,
        !best.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else { continue }
      // Vision's box is normalised with the origin at the bottom left.
      let box = observation.boundingBox
      lines.append([
        "text": best.string,
        "left": box.minX * width,
        "top": (1 - box.maxY) * height,
        "right": box.maxX * width,
        "bottom": (1 - box.minY) * height,
        "confidence": Double(best.confidence),
      ])
      all.append(best.string)
    }
    let language = NLLanguageRecognizer.dominantLanguage(for: all.joined(separator: " "))?.rawValue
    return ["lines": lines, "language": language ?? NSNull()]
  }
}

// END VisionOcr
