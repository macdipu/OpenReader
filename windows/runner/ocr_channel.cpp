#include "ocr_channel.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <functional>
#include <memory>
#include <string>
#include <thread>
#include <variant>
#include <vector>

#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Globalization.h>
#include <winrt/Windows.Graphics.Imaging.h>
#include <winrt/Windows.Media.Ocr.h>
#include <winrt/Windows.Storage.Streams.h>

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Result = flutter::MethodResult<EncodableValue>;

// UTF-8 <-> UTF-16, done by hand so nothing depends on which string helpers
// the installed C++/WinRT version has.
std::wstring Widen(const std::string& text) {
  if (text.empty()) return std::wstring();
  const int length = ::MultiByteToWideChar(CP_UTF8, 0, text.data(),
                                           static_cast<int>(text.size()), nullptr, 0);
  std::wstring out(static_cast<size_t>(length), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                        out.data(), length);
  return out;
}

std::string Narrow(const winrt::hstring& text) {
  if (text.empty()) return std::string();
  const int length = ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(),
                                           static_cast<int>(text.size()), nullptr,
                                           0, nullptr, nullptr);
  std::string out(static_cast<size_t>(length), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()),
                        out.data(), length, nullptr, nullptr);
  return out;
}

// A failure to report to Dart.
struct OcrError {
  std::string code;
  std::string message;
};

// The answer for Dart: either a value or an error, built off the platform
// thread and delivered on it.
struct OcrReply {
  bool ok = false;
  EncodableValue value;
  OcrError error;
};

winrt::Windows::Media::Ocr::OcrEngine CreateEngine(
    const std::vector<std::string>& languages) {
  using winrt::Windows::Globalization::Language;
  using winrt::Windows::Media::Ocr::OcrEngine;
  // A language the caller chose, if Windows has its OCR pack; otherwise the
  // languages in the user's profile (Windows has no automatic detection).
  for (const auto& code : languages) {
    if (code.empty()) continue;
    try {
      Language language{winrt::hstring(Widen(code))};
      if (OcrEngine::IsLanguageSupported(language)) {
        auto engine = OcrEngine::TryCreateFromLanguage(language);
        if (engine) return engine;
      }
    } catch (const winrt::hresult_error&) {
      // Not a language tag Windows understands: try the next one.
    }
  }
  return OcrEngine::TryCreateFromUserProfileLanguages();
}

OcrReply Recognize(const std::vector<uint8_t>& png,
                   const std::vector<std::string>& languages) {
  using namespace winrt::Windows::Graphics::Imaging;
  using namespace winrt::Windows::Storage::Streams;
  OcrReply reply;
  try {
    // Runs on a worker thread in the multithreaded apartment, where blocking
    // on an async operation with get() is allowed.
    auto engine = CreateEngine(languages);
    if (!engine) {
      reply.error = {"no_language",
                     "No OCR language is installed. Add one in Settings > "
                     "Time & language > Language & region, then try again."};
      return reply;
    }

    InMemoryRandomAccessStream stream;
    DataWriter writer(stream);
    writer.WriteBytes(winrt::array_view<const uint8_t>(png));
    writer.StoreAsync().get();
    writer.DetachStream();
    stream.Seek(0);

    auto decoder = BitmapDecoder::CreateAsync(stream).get();
    const uint32_t longest =
        (std::max)(decoder.PixelWidth(), decoder.PixelHeight());
    if (longest > winrt::Windows::Media::Ocr::OcrEngine::MaxImageDimension()) {
      reply.error = {"ocr_failed", "The page image is too large to read."};
      return reply;
    }
    auto bitmap = decoder
                      .GetSoftwareBitmapAsync(BitmapPixelFormat::Bgra8,
                                              BitmapAlphaMode::Premultiplied)
                      .get();
    auto result = engine.RecognizeAsync(bitmap).get();

    EncodableList lines;
    for (const auto& line : result.Lines()) {
      float left = 0, top = 0, right = 0, bottom = 0;
      bool first = true;
      for (const auto& word : line.Words()) {
        const auto box = word.BoundingRect();
        if (first) {
          left = box.X;
          top = box.Y;
          right = box.X + box.Width;
          bottom = box.Y + box.Height;
          first = false;
        } else {
          left = (std::min)(left, box.X);
          top = (std::min)(top, box.Y);
          right = (std::max)(right, box.X + box.Width);
          bottom = (std::max)(bottom, box.Y + box.Height);
        }
      }
      if (first) continue;  // a line with no words
      EncodableMap entry;
      entry[EncodableValue("text")] =
          EncodableValue(Narrow(line.Text()));
      entry[EncodableValue("left")] = EncodableValue(static_cast<double>(left));
      entry[EncodableValue("top")] = EncodableValue(static_cast<double>(top));
      entry[EncodableValue("right")] =
          EncodableValue(static_cast<double>(right));
      entry[EncodableValue("bottom")] =
          EncodableValue(static_cast<double>(bottom));
      lines.push_back(EncodableValue(std::move(entry)));
    }
    EncodableMap map;
    map[EncodableValue("lines")] = EncodableValue(std::move(lines));
    // The engine's language is the user's, not detected from the page; its
    // tag ("en-US") still tells the app which model read it.
    map[EncodableValue("language")] =
        EncodableValue(Narrow(engine.RecognizerLanguage().LanguageTag()));
    reply.ok = true;
    reply.value = EncodableValue(std::move(map));
  } catch (const winrt::hresult_error& e) {
    reply.error = {"ocr_failed", Narrow(e.message())};
  } catch (const std::exception& e) {
    reply.error = {"ocr_failed", e.what()};
  }
  return reply;
}

// Hands [task] to the window, to run on the platform thread.
void PostToPlatformThread(HWND window, std::function<void()> task) {
  auto* heap = new std::function<void()>(std::move(task));
  if (!::PostMessage(window, kRunOnPlatformThreadMessage, 0,
                     reinterpret_cast<LPARAM>(heap))) {
    delete heap;
  }
}

}  // namespace

void RegisterOcrChannel(flutter::BinaryMessenger* messenger, HWND window) {
  // The channel must outlive this call: the engine keeps its handler.
  static auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger, "openreader/ocr",
          &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [window](const flutter::MethodCall<EncodableValue>& call,
               std::unique_ptr<Result> result) {
        if (call.method_name() != "recognize") {
          result->NotImplemented();
          return;
        }
        const auto* args = std::get_if<EncodableMap>(call.arguments());
        if (!args) {
          result->Error("bad_arguments", "Expected a map");
          return;
        }
        std::vector<uint8_t> png;
        std::vector<std::string> languages;
        const auto png_it = args->find(EncodableValue("png"));
        if (png_it != args->end()) {
          if (const auto* bytes =
                  std::get_if<std::vector<uint8_t>>(&png_it->second)) {
            png = *bytes;
          }
        }
        const auto lang_it = args->find(EncodableValue("languages"));
        if (lang_it != args->end()) {
          if (const auto* list = std::get_if<EncodableList>(&lang_it->second)) {
            for (const auto& item : *list) {
              if (const auto* code = std::get_if<std::string>(&item)) {
                languages.push_back(*code);
              }
            }
          }
        }
        if (png.empty()) {
          result->Error("bad_arguments", "No image");
          return;
        }

        // The recognizer takes a while: do it off the platform thread, then
        // answer on it (a MethodResult must be used on the thread it came
        // on).
        std::shared_ptr<Result> shared(std::move(result));
        std::thread([window, shared, png = std::move(png),
                     languages = std::move(languages)]() {
          winrt::init_apartment(winrt::apartment_type::multi_threaded);
          auto reply = std::make_shared<OcrReply>(Recognize(png, languages));
          PostToPlatformThread(window, [shared, reply]() {
            if (reply->ok) {
              shared->Success(reply->value);
            } else {
              shared->Error(reply->error.code, reply->error.message);
            }
          });
        }).detach();
      });
}
