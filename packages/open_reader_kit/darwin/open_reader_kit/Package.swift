// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "open_reader_kit",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_13),
    ],
    products: [
        .library(
            name: "open-reader-kit",
            targets: ["open_reader_kit"]
        ),
    ],
    targets: [
        .target(
            name: "open_reader_kit",
            dependencies: [
                .target(name: "PDFium"),
            ],
            path: "Sources/main"
        ),
        .binaryTarget(
            name: "PDFium",
            url: "https://github.com/espresso3389/pdfium-xcframework/releases/download/v144.0.7811.0-20260502-190206/PDFium-chromium-7811-20260502-190206.xcframework.zip",
            checksum: "948d9257f53f01cbed74b81bb8adc8758e52ac9390751772de7889026d32d5a1"
        ),
    ]
)
