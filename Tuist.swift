import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: ["26.0", "26.0.1", "26.1", "26.2", "26.4", "26.4.1"],
        swiftVersion: "6.0"
    )
)
