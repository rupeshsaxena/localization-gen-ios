import XCTest
@testable import LocalizationToolCore

final class CSVParserTests: XCTestCase {

    // MARK: - Happy path

    func testBasicParsing() throws {
        let csv = """
        id,key,en,fr
        greeting,hello,Hello,Bonjour
        farewell,bye,Goodbye,Au revoir
        """
        let data = try CSVParser.parse(content: csv)

        XCTAssertEqual(data.locales, ["en", "fr"])
        XCTAssertEqual(data.rows.count, 2)
        XCTAssertEqual(data.rows[0].id, "greeting")
        XCTAssertEqual(data.rows[0].key, "hello")
        XCTAssertEqual(data.rows[0].translations["en"], "Hello")
        XCTAssertEqual(data.rows[0].translations["fr"], "Bonjour")
        XCTAssertEqual(data.rows[1].key, "bye")
    }

    func testQuotedFieldsWithCommas() throws {
        let csv = #"id,key,en"# + "\n" +
                  #"welcome,welcome,"Welcome, World!""# + "\n"
        let data = try CSVParser.parse(content: csv)

        XCTAssertEqual(data.rows[0].translations["en"], "Welcome, World!")
    }

    func testEscapedQuotesInsideField() throws {
        let csv = "id,key,en\n" +
                  "q,quote,\"He said \"\"Hello\"\"\"\n"
        let data = try CSVParser.parse(content: csv)

        XCTAssertEqual(data.rows[0].translations["en"], #"He said "Hello""#)
    }

    func testMultilineQuotedField() throws {
        let csv = "id,key,en\n" +
                  "ml,multi,\"Line one\nLine two\"\n"
        let data = try CSVParser.parse(content: csv)

        XCTAssertEqual(data.rows[0].translations["en"], "Line one\nLine two")
    }

    func testWindowsLineEndings() throws {
        let csv = "id,key,en\r\ngreeting,hello,Hello\r\n"
        let data = try CSVParser.parse(content: csv)

        XCTAssertEqual(data.rows.count, 1)
        XCTAssertEqual(data.rows[0].translations["en"], "Hello")
    }

    func testBOMStripping() throws {
        let csv = "\u{FEFF}id,key,en\ngreeting,hello,Hello\n"
        let data = try CSVParser.parse(content: csv)
        XCTAssertEqual(data.rows.count, 1)
    }

    func testEmptyCellSkipped() throws {
        let csv = "id,key,en,fr\n" +
                  "greeting,hello,Hello,\n"   // fr is empty
        let data = try CSVParser.parse(content: csv)

        XCTAssertNotNil(data.rows[0].translations["en"])
        XCTAssertNil(data.rows[0].translations["fr"])
    }

    func testBlankRowsIgnored() throws {
        let csv = "id,key,en\n\ngreeting,hello,Hello\n\n"
        let data = try CSVParser.parse(content: csv)
        XCTAssertEqual(data.rows.count, 1)
    }

    // MARK: - Error cases

    func testEmptyFileThrows() {
        XCTAssertThrowsError(try CSVParser.parse(content: ""))
        XCTAssertThrowsError(try CSVParser.parse(content: "\n\n"))
    }

    func testInvalidHeaderThrows() {
        let csv = "foo,bar,en\nid1,key1,Hello\n"
        XCTAssertThrowsError(try CSVParser.parse(content: csv))
    }

    func testUnterminatedQuoteThrows() {
        let csv = "id,key,en\ngreeting,hello,\"unterminated\n"
        XCTAssertThrowsError(try CSVParser.parse(content: csv))
    }
}

// MARK: - StringsFileGenerator tests

final class StringsFileGeneratorTests: XCTestCase {

    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testOutputDirectoryAndFileCreation() throws {
        let data = try CSVParser.parse(content: "id,key,en,fr\ngreeting,hello,Hello,Bonjour\n")
        let results = try StringsFileGenerator.generate(from: data, outputDirectory: tempDir)

        XCTAssertEqual(results.count, 2)
        for result in results {
            XCTAssertTrue(FileManager.default.fileExists(atPath: result.fileURL.path))
        }
    }

    func testGeneratedFileContent() throws {
        let data = try CSVParser.parse(content: "id,key,en\ngreet,hello,Hello World\n")
        let results = try StringsFileGenerator.generate(from: data, outputDirectory: tempDir)

        let content = try String(contentsOf: results[0].fileURL, encoding: .utf8)
        XCTAssertTrue(content.contains("\"hello\" = \"Hello World\";"))
        XCTAssertTrue(content.contains("/* greet */"))
    }

    func testSpecialCharactersAreEscaped() throws {
        let csv = "id,key,en\n" +
                  #"q,say,"She said \"hi\" & \\"# + "\n"
        // value: She said "hi" & \
        let csv2 = "id,key,en\nq,say,\"She said \\\"hi\\\" & \\\\\"\n"
        let data = try CSVParser.parse(content: "id,key,en\nq,say,\"value with \\\"quotes\\\"\"\n")
        let results = try StringsFileGenerator.generate(from: data, outputDirectory: tempDir)
        let content = try String(contentsOf: results[0].fileURL, encoding: .utf8)
        // Quotes in the value must be escaped
        XCTAssertTrue(content.contains("\\\""))
        _ = csv; _ = csv2 // silence unused warnings
    }

    func testKeyCountInResult() throws {
        let csv = "id,key,en,fr\n" +
                  "a,key1,Hello,Bonjour\n" +
                  "b,key2,World,\n"           // fr missing
        let data = try CSVParser.parse(content: csv)
        let results = try StringsFileGenerator.generate(from: data, outputDirectory: tempDir)

        let enResult = results.first { $0.locale == "en" }!
        let frResult = results.first { $0.locale == "fr" }!
        XCTAssertEqual(enResult.keyCount, 2)
        XCTAssertEqual(frResult.keyCount, 1)
    }
}
