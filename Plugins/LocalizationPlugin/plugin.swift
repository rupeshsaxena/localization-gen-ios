import PackagePlugin
import Foundation

/// A SPM `BuildToolPlugin` that converts every `*.csv` file found in the applying
/// target's source directory into `<locale>.lproj/Localizable.strings` files.
///
/// The generated files are placed in the plugin's work directory and are
/// automatically bundled as localized resources in the consuming target.
///
/// # How to use
/// Add the plugin to a target in `Package.swift`:
/// ```swift
/// .target(
///     name: "MyApp",
///     resources: [.process("Resources")],
///     plugins: [.plugin(name: "LocalizationPlugin", package: "LocalizationGenerator")]
/// )
/// ```
/// Then place a CSV file (e.g. `Localizations.csv`) inside that target's source
/// directory. The plugin picks up any `*.csv` file automatically.
@main
struct LocalizationPlugin: BuildToolPlugin {

    func createBuildCommands(
        context: PluginContext,
        target: Target
    ) async throws -> [Command] {

        // Locate all .csv files directly inside the target's source directory.
        // Adjust to a recursive search if you nest CSV files inside subdirectories.
        let csvFiles = try csvFiles(in: target.directory)

        guard !csvFiles.isEmpty else {
            // No CSV files → nothing to do.
            return []
        }

        let tool      = try context.tool(named: "LocalizationTool")
        let outputDir = context.pluginWorkDirectory.appending("GeneratedLocalizations")

        return csvFiles.map { csvFile in
            // `prebuildCommand` runs before the build starts and its output directory
            // is scanned for generated files that are added to the module.
            Command.prebuildCommand(
                displayName: "LocalizationPlugin: generating strings from \(csvFile.lastComponent)",
                executable: tool.path,
                arguments: [
                    "--input",  csvFile.string,
                    "--output", outputDir.string
                ],
                outputFilesDirectory: outputDir
            )
        }
    }

    // MARK: - Helpers

    private func csvFiles(in directory: Path) throws -> [Path] {
        let contents = try FileManager.default
            .contentsOfDirectory(atPath: directory.string)
        return contents
            .filter { $0.hasSuffix(".csv") }
            .sorted()                          // deterministic order
            .map { directory.appending($0) }
    }
}

// MARK: - Xcode project support

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension LocalizationPlugin: XcodeBuildToolPlugin {

    func createBuildCommands(
        context: XcodePluginContext,
        target: XcodeTarget
    ) throws -> [Command] {

        // For Xcode targets, scan the target's input files for CSV files
        let csvInputFiles = target.inputFiles
            .filter { $0.path.extension == "csv" }

        guard !csvInputFiles.isEmpty else { return [] }

        let tool      = try context.tool(named: "LocalizationTool")
        let outputDir = context.pluginWorkDirectory.appending("GeneratedLocalizations")

        return csvInputFiles.map { csvFile in
            Command.prebuildCommand(
                displayName: "LocalizationPlugin: generating strings from \(csvFile.path.lastComponent)",
                executable: tool.path,
                arguments: [
                    "--input",  csvFile.path.string,
                    "--output", outputDir.string
                ],
                outputFilesDirectory: outputDir
            )
        }
    }
}
#endif
