// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SparkKit",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
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
