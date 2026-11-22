// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "danky",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/dduan/TOMLDecoder", exact: "0.4.4"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
    ],
    targets: [
        // Private SkyLight and CGS calls. Objective-C, capability checked, nothing else lives here.
        .target(
            name: "DankyPrivate",
            linkerSettings: [
                .unsafeFlags(["-F/System/Library/PrivateFrameworks", "-framework", "SkyLight"]),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
            ]
        ),
        // Pure layout engine: trees, rectangles, no AppKit. Fully unit tested.
        .target(
            name: "DankyLayout",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DankyLayoutTests",
            dependencies: ["DankyLayout"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The command vocabulary shared by bindings, CLI and menu: parsing and reference. Unit tested.
        .target(
            name: "DankyCommands",
            dependencies: ["DankyLayout", "DankyConfig"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DankyCommandsTests",
            dependencies: ["DankyCommands", "DankyConfig", .product(name: "TOMLDecoder", package: "TOMLDecoder")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Config types and TOML loading. No AppKit; Carbon.HIToolbox for the key codes only. Unit tested.
        .target(
            name: "DankyConfig",
            dependencies: [.product(name: "TOMLDecoder", package: "TOMLDecoder")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DankyConfigTests",
            dependencies: ["DankyConfig"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Reading and writing the CLI socket. Foundation only. Unit tested.
        .target(
            name: "DankySocket",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "DankySocketTests",
            dependencies: ["DankySocket"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The app and CLI.
        .executableTarget(
            name: "danky",
            dependencies: [
                "DankyPrivate", "DankyLayout", "DankyConfig", "DankyCommands", "DankySocket",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)],
            // The app bundle carries Sparkle.framework in Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "DankyAppTests",
            dependencies: ["danky", "DankyConfig", "DankyPrivate"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
