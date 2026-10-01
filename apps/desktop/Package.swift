// swift-tools-version: 6.2
import PackageDescription

// Three layers, one direction of dependency:
//   MulchCore  rules, scanning, cleaning, persistence. No SwiftUI, no AppKit.
//   MulchUI    presentational SwiftUI. Knows nothing about MulchCore.
//   Mulch      the app: composes the two, owns state and system integrations.
let package = Package(
    name: "Mulch",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "MulchCore"),
        .target(
            name: "MulchUI",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .executableTarget(
            name: "Mulch",
            dependencies: ["MulchCore", "MulchUI"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "MulchCoreTests", dependencies: ["MulchCore"]),
    ]
)
