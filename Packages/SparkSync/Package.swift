// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SparkSync",
    platforms: [.iOS(.v26)],
    products: [.library(name: "SparkSync", targets: ["SparkSync"])],
    dependencies: [.package(path: "../SparkKit")],
    targets: [
        .target(
            name: "SparkSync",
            dependencies: ["SparkKit"],
            path: "Sources/SparkSync",
            linkerSettings: [
                .linkedFramework("BackgroundTasks"),
                .linkedFramework("WidgetKit"),
            ]
        ),
    ]
)
