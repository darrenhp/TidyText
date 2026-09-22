// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TidyText",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TidyText", targets: ["TidyText"])
    ],
    targets: [
        .executableTarget(
            name: "TidyText",
            dependencies: [],
            path: "Sources/TidyText",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security")
            ]
        )
    ]
)
