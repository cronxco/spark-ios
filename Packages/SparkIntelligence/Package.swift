// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SparkIntelligence",
    platforms: [.iOS(.v27)],
    products: [.library(name: "SparkIntelligence", targets: ["SparkIntelligence"])],
    dependencies: [.package(path: "../SparkKit")],
    targets: [
        .target(
            name: "SparkIntelligence",
            dependencies: ["SparkKit"],
            path: "Sources/SparkIntelligence"
        ),
        .testTarget(
            name: "SparkIntelligenceTests",
            dependencies: ["SparkIntelligence", "SparkKit"],
            path: "Tests/SparkIntelligenceTests"
        ),
    ]
)
