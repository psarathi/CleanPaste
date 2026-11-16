import XCTest
@testable import CleanPasteCore

final class ColorParserTests: XCTestCase {
    func testHexParsing() {
        let c1 = ColorParser.parse("#FF5733")
        XCTAssertNotNil(c1)
        XCTAssertEqual(c1?.hexString, "#FF5733")
        XCTAssertEqual(c1?.rgbString, "rgb(255, 87, 51)")

        let c2 = ColorParser.parse("#f0a")
        XCTAssertNotNil(c2)
        XCTAssertEqual(c2?.hexString, "#FF00AA")

        let c3 = ColorParser.parse("#11223380")
        XCTAssertNotNil(c3)
        XCTAssertEqual(c3?.hexString, "#11223380")
    }

    func testRGBAndHSLParsing() {
        let rgb = ColorParser.parse("rgb(34, 139, 230)")
        XCTAssertNotNil(rgb)
        XCTAssertEqual(rgb?.hexString, "#228BE6")

        let rgba = ColorParser.parse("rgba(255, 255, 255, 0.50)")
        XCTAssertNotNil(rgba)
        XCTAssertEqual(rgba?.alpha ?? 0, 0.5, accuracy: 0.01)

        let hsl = ColorParser.parse("hsl(120, 100%, 50%)")
        XCTAssertNotNil(hsl)
        XCTAssertEqual(hsl?.hexString, "#00FF00")
    }

    func testInvalidStringsReturnNil() {
        XCTAssertNil(ColorParser.parse("hello world"))
        XCTAssertNil(ColorParser.parse("FF5733"))
        XCTAssertNil(ColorParser.parse("#GGGGGG"))
        XCTAssertNil(ColorParser.parse("rgb(1, 2)"))
    }

    func testLuminanceContrast() {
        XCTAssertEqual(ColorParser.parse("#FFFFFF")?.isLight, true)
        XCTAssertEqual(ColorParser.parse("#101010")?.isLight, false)
    }
}
