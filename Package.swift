// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "explicitDependencyImportCheck",
    products: [
        .plugin(
            name: "explicitDependencyImportCheckPlugin",
            targets: ["explicitDependencyImportCheckPlugin"]
        )
    ],
    targets: [
        .plugin(
            name: "explicitDependencyImportCheckPlugin",
            capability: .buildTool(),
            dependencies: ["sitrepExplicitDependencyImportCheck"]
        ),
        .binaryTarget(name: "sitrepExplicitDependencyImportCheck", path: "./artifactbundles/Sitrep.artifactbundle")
    ]
)
