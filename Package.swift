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
            dependencies: ["sitrep"]
        ),
        .binaryTarget(name: "sitrep", path: "./artifactbundles/sitrep.artifactbundle")
    ]
)
