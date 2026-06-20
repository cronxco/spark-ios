// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SparkKit",
    platforms: [
        .macOS(.v15),
        .iOS(.v27),
        .watchOS(.v27),
    ],
    products: [
        .library(name: "SparkKit", targets: ["SparkKit"]),
    ],
    targets: [
        .target(
            name: "SparkKit",
            path: "Sources/SparkKit"
        ),
        .testTarget(
            name: "SparkKitTests",
            dependencies: ["SparkKit"],
            path: "Tests/SparkKitTests"
        ),
    ]
)
