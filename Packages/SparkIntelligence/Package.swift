// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SparkIntelligence",
    platforms: [.iOS(.v26)],
    products: [.library(name: "SparkIntelligence", targets: ["SparkIntelligence"])],
    dependencies: [.package(path: "../SparkKit")],
    targets: [
        .target(
            name: "SparkIntelligence",
            dependencies: ["SparkKit"],
            path: "Sources/SparkIntelligence"
        ),
    ]
)
