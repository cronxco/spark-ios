import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        // Project targets iOS 27 (Xcode 27) but generation is allowed on any
        // Xcode so the project can be generated/inspected on older toolchains.
        // A full build/test still requires Xcode 27's iOS 27 SDK.
        compatibleXcodeVersions: .all,
        swiftVersion: "6.0"
    )
)
