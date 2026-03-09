/// RFC 4180-compliant CSV parser that understands the localization file format:
///   id,key,<locale-1>,<locale-2>,...
public struct CSVParser {

    public struct ParsedData {
        public let locales: [String]
        public let rows: [Row]

        public struct Row {
            public let id: String
            public let key: String
            /// Maps locale code → translated string (absent when cell is empty).
            public let translations: [String: String]
        }
    }

    public enum ParseError: Error, CustomStringConvertible {
        case emptyFile
        case invalidHeader(found: [String])
        case unterminatedQuote(line: Int)

        public var description: String {
            switch self {
            case .emptyFile:
                return "The CSV file is empty."
            case .invalidHeader(let found):
                return "Expected header 'id,key,<locale>,...' but found: \(found.joined(separator: ","))"
            case .unterminatedQuote(let line):
                return "Unterminated quoted field starting near line \(line)."
            }
        }
    }

    public static func parse(content: String) throws -> ParsedData {
        // Normalize BOM and line endings
        var text = content
        if text.hasPrefix("\u{FEFF}") { text = String(text.dropFirst()) }
        text = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        if text.isEmpty { throw ParseError.emptyFile }

        var allRows = try tokenize(text)

        // Skip leading blank rows
        allRows.removeAll { $0.allSatisfy(\.isEmpty) }
        guard !allRows.isEmpty else { throw ParseError.emptyFile }

        let header = allRows.removeFirst().map { $0.trimmingCharacters(in: .whitespaces) }
        guard header.count >= 3,
              header[0].lowercased() == "id",
              header[1].lowercased() == "key" else {
            throw ParseError.invalidHeader(found: header)
        }

        let locales = Array(header.dropFirst(2))

        let rows: [ParsedData.Row] = allRows.compactMap { fields in
            // Skip rows that are entirely blank
            guard !fields.allSatisfy(\.isEmpty) else { return nil }

            let id  = fields[0].trimmingCharacters(in: .whitespaces)
            let key = fields.count > 1 ? fields[1].trimmingCharacters(in: .whitespaces) : ""
            guard !key.isEmpty else { return nil }

            var translations: [String: String] = [:]
            for (idx, locale) in locales.enumerated() {
                let valueIdx = idx + 2
                if valueIdx < fields.count, !fields[valueIdx].isEmpty {
                    translations[locale] = fields[valueIdx]
                }
            }

            return ParsedData.Row(id: id, key: key, translations: translations)
        }

        return ParsedData(locales: locales, rows: rows)
    }

    // MARK: - Tokenizer

    /// Splits the full CSV text into rows and fields, handling:
    ///   - Quoted fields (commas and newlines inside quotes are part of the field)
    ///   - Escaped quotes (`""` → `"`)
    private static func tokenize(_ text: String) throws -> [[String]] {
        var rows:    [[String]] = []
        var row:     [String]  = []
        var field    = ""
        var inQuotes = false
        var lineNum  = 1
        var i        = text.startIndex

        while i < text.endIndex {
            let ch = text[i]

            if inQuotes {
                if ch == "\"" {
                    let next = text.index(after: i)
                    if next < text.endIndex && text[next] == "\"" {
                        // Escaped double-quote inside a quoted field
                        field.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    if ch == "\n" { lineNum += 1 }
                    field.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    inQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n":
                    row.append(field)
                    field = ""
                    rows.append(row)
                    row = []
                    lineNum += 1
                default:
                    field.append(ch)
                }
            }

            i = text.index(after: i)
        }

        // Flush the last field / row
        if inQuotes { throw ParseError.unterminatedQuote(line: lineNum) }
        row.append(field)
        if !row.allSatisfy(\.isEmpty) { rows.append(row) }

        return rows
    }
}
