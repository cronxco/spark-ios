// swift-tools-version: 6.4
import Foundation
import PackageDescription

/// Siri AI tool intents (`@AppIntent(.tool)`) need the iOS 27.3 SDK, which
/// ships only with the Xcode 27.3 beta. They are compiled in when
/// `SPARK_SIRI_AI_TOOLS=1` is in the environment that resolves this package,
/// so every other build, CI included, works on the released Xcode. Remove
/// the gate once Xcode 27.3 is the project's minimum.
let siriAITools = ProcessInfo.processInfo.environment["SPARK_SIRI_AI_TOOLS"] == "1"

let package = Package(
    name: "SparkIntelligence",
    platforms: [.macOS(.v27), .iOS(.v27)],
    products: [.library(name: "SparkIntelligence", targets: ["SparkIntelligence"])],
    dependencies: [.package(path: "../SparkKit")],
    targets: [
        .target(
            name: "SparkIntelligence",
            dependencies: ["SparkKit"],
            path: "Sources/SparkIntelligence",
            swiftSettings: siriAITools ? [.define("SPARK_SIRI_AI_TOOLS")] : []
        ),
        .testTarget(
            name: "SparkIntelligenceTests",
            dependencies: ["SparkIntelligence", "SparkKit"],
            path: "Tests/SparkIntelligenceTests"
        ),
    ]
)
