// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "LocalizationGenerator",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // Expose the plugin so consuming packages can apply it to their targets
        .plugin(
            name: "LocalizationPlugin",
            targets: ["LocalizationPlugin"]
        )
    ],
    targets: [
        // The CLI tool that does the actual CSV → .strings conversion
        .executableTarget(
            name: "LocalizationTool",
            dependencies: ["LocalizationToolCore"],
            path: "Sources/LocalizationTool"
        ),
        // The SPM BuildToolPlugin that invokes LocalizationTool at build time
        .plugin(
            name: "LocalizationPlugin",
            capability: .buildTool(),
            dependencies: ["LocalizationTool"],
            path: "Plugins/LocalizationPlugin"
        ),
        // Unit tests for the core parsing and generation logic
        .testTarget(
            name: "LocalizationToolTests",
            dependencies: ["LocalizationToolCore"],
            path: "Tests/LocalizationToolTests"
        ),
        // Shared library so both the CLI and tests can import the same code
        .target(
            name: "LocalizationToolCore",
            path: "Sources/LocalizationToolCore"
        )
    ]
)
