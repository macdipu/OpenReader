# open_reader_kit example

A small app that shows two ways to use open_reader_kit:
- **DocumentViewer:** type the path of any supported file and open it. The reading position is kept in memory and restored when you open the same file again.
- **Word reader with search:** a `WordDocumentController` and `WordDocumentView`, with search and the continuous/print layout switch in the app bar.

The example has no file picker, to keep its only dependency the kit. Enter an absolute path to a file the app is allowed to read (on a phone, a file in the app's own storage; on macOS, mind the app sandbox).

## Run it

Only `lib/` and `pubspec.yaml` are checked in. Generate the platform folders you want, then run:

```sh
flutter create --platforms=android,ios,macos,windows,linux .
flutter run
```

The first build downloads PDFium for the target platform (see the kit's README).
