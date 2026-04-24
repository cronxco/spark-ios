// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SparkUI",
    platforms: [
        .iOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        .library(name: "SparkUI", targets: ["SparkUI"]),
    ],
    dependencies: [
        .package(path: "../SparkKit"),
    ],
    targets: [
        .target(
            name: "SparkUI",
            dependencies: ["SparkKit"],
            path: "Sources/SparkUI"
        ),
        .testTarget(
            name: "SparkUITests",
            dependencies: ["SparkUI"],
            path: "Tests/SparkUITests"
        ),
    ]
)
