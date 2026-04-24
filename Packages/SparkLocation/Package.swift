// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SparkLocation",
    platforms: [.iOS(.v26)],
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
