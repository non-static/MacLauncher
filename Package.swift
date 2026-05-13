// swift-tools-version: 6.0

import PackageDescription
import Foundation

let developerFrameworkSearchPaths = [
    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
    "/Applications/Xcode.app/Contents/Developer/Library/Frameworks"
].filter { FileManager.default.fileExists(atPath: $0) }

let developerLibrarySearchPaths = [
    "/Library/Developer/CommandLineTools/Library/Developer/usr/lib",
    "/Applications/Xcode.app/Contents/Developer/usr/lib"
].filter { FileManager.default.fileExists(atPath: $0) }

let testLinkerSettings: [LinkerSetting] =
    developerFrameworkSearchPaths.flatMap {
        [
            .unsafeFlags(["-F", $0]),
            .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", $0])
        ]
    } +
    developerLibrarySearchPaths.map {
        .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", $0])
    }

let package = Package(
    name: "MacLauncher",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "MacLauncher", targets: ["MacLauncher"]),
        .library(name: "MacLauncherCore", targets: ["MacLauncherCore"])
    ],
    targets: [
        .target(name: "MacLauncherCore"),
        .executableTarget(
            name: "MacLauncher",
            dependencies: ["MacLauncherCore"]
        ),
        .testTarget(
            name: "MacLauncherCoreTests",
            dependencies: ["MacLauncherCore"],
            swiftSettings: developerFrameworkSearchPaths.map {
                .unsafeFlags(["-F", $0])
            },
            linkerSettings: testLinkerSettings
        )
    ]
)
