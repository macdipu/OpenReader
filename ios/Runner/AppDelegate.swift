import Flutter
import NaturalLanguage
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // OCR for scanned PDF pages through Apple Vision (CR-READER-SELECT-OCR SO-14);
    // the same channel and contract as macOS.
    let channel = FlutterMethodChannel(
      name: "openreader/ocr", binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
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
    ocrChannel = channel
  }

  private var ocrChannel: FlutterMethodChannel?
}

// BEGIN VisionOcr (kept free of Flutter types so it can be compiled and tried on its own)

/// Text recognition through Apple Vision: on the device, no network. The
/// language is detected by Vision itself on iOS 16 and later; `languages`
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
    } else if #available(iOS 16.0, *) {
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

