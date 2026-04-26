// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SparkHealth",
    platforms: [.iOS(.v26)],
    products: [.library(name: "SparkHealth", targets: ["SparkHealth"])],
    dependencies: [.package(path: "../SparkKit")],
    targets: [
        .target(
            name: "SparkHealth",
            dependencies: ["SparkKit"],
            path: "Sources/SparkHealth",
            linkerSettings: [
                .linkedFramework("HealthKit"),
            ]
        ),
        .testTarget(
            name: "SparkHealthTests",
            dependencies: ["SparkHealth"],
            path: "Tests/SparkHealthTests"
        ),
    ]
)
