// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanPaste",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CleanPasteCore", targets: ["CleanPasteCore"]),
        .executable(name: "CleanPaste", targets: ["CleanPaste"])
    ],
    targets: [
        .target(
            name: "CleanPasteCore",
            path: "Sources/CleanPasteCore",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("LinkPresentation"),
                .linkedFramework("QuickLookThumbnailing"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UniformTypeIdentifiers"),
                .linkedFramework("Vision")
            ]
        ),
        .executableTarget(
            name: "CleanPaste",
            dependencies: ["CleanPasteCore"],
            path: "Sources/CleanPasteApp",
            exclude: [
                "Resources"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("QuickLookUI")
            ]
        ),
        .testTarget(
            name: "CleanPasteTests",
            dependencies: ["CleanPasteCore"],
            path: "Tests/CleanPasteTests",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
