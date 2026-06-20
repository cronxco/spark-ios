// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "SparkLocation",
    platforms: [.iOS(.v27)],
    products: [.library(name: "SparkLocation", targets: ["SparkLocation"])],
    dependencies: [.package(path: "../SparkKit")],
    targets: [
        .target(
            name: "SparkLocation",
            dependencies: ["SparkKit"],
            path: "Sources/SparkLocation"
        ),
    ]
)
