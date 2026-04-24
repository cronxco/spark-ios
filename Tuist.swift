import ProjectDescription

let tuist = Tuist(
    project: .tuist(
        compatibleXcodeVersions: ["26.0", "26.1", "26.2"],
        swiftVersion: "6.0"
    )
)
