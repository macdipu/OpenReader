#ifndef RUNNER_OCR_CHANNEL_H_
#define RUNNER_OCR_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <windows.h>

// Window message that runs a std::function<void()> on the window's own
// (platform) thread; the OCR worker uses it to answer Dart there. lparam owns
// a heap-allocated std::function<void()>.
constexpr UINT kRunOnPlatformThreadMessage = WM_APP + 0x0C;

// Registers the "openreader/ocr" channel: `recognize` reads text from a PNG with
// Windows.Media.Ocr, entirely on the device (CR-READER-SELECT-OCR SO-14).
//
//   arguments: {png: Uint8List, languages: List<String>}
//   reply:     {lines: [{text, left, top, right, bottom}], language: String?}
//              boxes in image pixels from the top-left.
//
// Errors: "no_language" when no OCR language is installed for the user's
// languages (the message says how to add one), "ocr_failed" otherwise.
void RegisterOcrChannel(flutter::BinaryMessenger* messenger, HWND window);

#endif  // RUNNER_OCR_CHANNEL_H_
