// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "scuttle",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/dduan/TOMLDecoder", exact: "0.4.4"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
    ],
    targets: [
        // Private SkyLight and CGS calls. Objective-C, capability checked, nothing else lives here.
        .target(
            name: "ScuttlePrivate",
            linkerSettings: [
                .unsafeFlags(["-F/System/Library/PrivateFrameworks", "-framework", "SkyLight"]),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("AppKit"),
            ]
        ),
        // Pure layout engine: trees, rectangles, no AppKit. Fully unit tested.
        .target(
            name: "ScuttleLayout",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ScuttleLayoutTests",
            dependencies: ["ScuttleLayout"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The command vocabulary shared by bindings, CLI and menu: parsing and reference. Unit tested.
        .target(
            name: "ScuttleCommands",
            dependencies: ["ScuttleLayout", "ScuttleConfig"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ScuttleCommandsTests",
            dependencies: ["ScuttleCommands", "ScuttleConfig", .product(name: "TOMLDecoder", package: "TOMLDecoder")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Config types and TOML loading. No AppKit; Carbon.HIToolbox for the key codes only. Unit tested.
        .target(
            name: "ScuttleConfig",
            dependencies: [.product(name: "TOMLDecoder", package: "TOMLDecoder")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ScuttleConfigTests",
            dependencies: ["ScuttleConfig"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Reading and writing the CLI socket. Foundation only. Unit tested.
        .target(
            name: "ScuttleSocket",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ScuttleSocketTests",
            dependencies: ["ScuttleSocket"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The app and CLI.
        .executableTarget(
            name: "scuttle",
            dependencies: [
                "ScuttlePrivate", "ScuttleLayout", "ScuttleConfig", "ScuttleCommands", "ScuttleSocket",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)],
            // The app bundle carries Sparkle.framework in Contents/Frameworks.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .testTarget(
            name: "ScuttleAppTests",
            dependencies: ["scuttle", "ScuttleConfig", "ScuttlePrivate"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
