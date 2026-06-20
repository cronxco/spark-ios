// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SparkUI",
    platforms: [
        .iOS(.v27),
        .watchOS(.v27),
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
            path: "Sources/SparkUI",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "SparkUITests",
            dependencies: ["SparkUI"],
            path: "Tests/SparkUITests"
        ),
    ]
)
