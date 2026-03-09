import Foundation
import LocalizationToolCore

// MARK: - Argument parsing

struct CLI {
    let inputPath:  String
    let outputPath: String
    let verbose:    Bool

    static func parse() -> CLI? {
        var inputPath:  String?
        var outputPath: String?
        var verbose = false

        var args = Array(CommandLine.arguments.dropFirst()).makeIterator()
        while let arg = args.next() {
            switch arg {
            case "--input",  "-i": inputPath  = args.next()
            case "--output", "-o": outputPath = args.next()
            case "--verbose", "-v": verbose = true
            case "--help", "-h":
                printUsage()
                exit(0)
            default:
                printError("Unknown argument: '\(arg)'")
                printUsage()
                exit(1)
            }
        }

        guard let i = inputPath, let o = outputPath else { return nil }
        return CLI(inputPath: i, outputPath: o, verbose: verbose)
    }

    static func printUsage() {
        print("""
        USAGE: LocalizationTool --input <csv-file> --output <output-directory> [--verbose]

        ARGUMENTS:
          --input,   -i   Path to the CSV localization file (required)
          --output,  -o   Directory where .lproj folders will be generated (required)
          --verbose, -v   Print detailed per-key output
          --help,    -h   Show this message

        CSV FORMAT:
          The first row must be the header:
            id,key,<locale-1>,<locale-2>,...

          Example:
            id,key,en,fr,es
            greeting,hello_world,"Hello, World!","Bonjour le monde !","¡Hola, Mundo!"

        OUTPUT:
          <output-directory>/
            en.lproj/Localizable.strings
            fr.lproj/Localizable.strings
            es.lproj/Localizable.strings
        """)
    }
}

// MARK: - Entry point

func run() throws {
    guard let cli = CLI.parse() else {
        printError("Missing required arguments --input and --output.")
        CLI.printUsage()
        exit(1)
    }

    let inputURL  = URL(fileURLWithPath: cli.inputPath)
    let outputURL = URL(fileURLWithPath: cli.outputPath)

    // Read & parse
    print("Parsing: \(inputURL.lastPathComponent)")
    let content: String
    do {
        content = try String(contentsOf: inputURL, encoding: .utf8)
    } catch {
        throw ExitError("Cannot read '\(cli.inputPath)': \(error.localizedDescription)")
    }

    let data = try CSVParser.parse(content: content)
    print("  Locales : \(data.locales.joined(separator: ", "))")
    print("  Keys    : \(data.rows.count)")

    // Generate
    let results = try StringsFileGenerator.generate(from: data, outputDirectory: outputURL)

    for result in results {
        let label = cli.verbose
            ? "  -> \(result.locale).lproj/Localizable.strings (\(result.keyCount) keys)"
            : "  -> \(result.locale).lproj/Localizable.strings"
        print(label)
    }

    print("Done: \(results.count) file(s) written to \(outputURL.path)")
}

// MARK: - Helpers

struct ExitError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { self.description = message }
}

func printError(_ message: String) {
    fputs("error: \(message)\n", stderr)
}

do {
    try run()
} catch let exit as ExitError {
    printError(exit.description)
    Foundation.exit(1)
} catch {
    printError(error.localizedDescription)
    Foundation.exit(1)
}
