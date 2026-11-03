import XCTest
@testable import QuickCastCore

final class KeystrokeTests: XCTestCase {
    func testShortcutOrderAndLayoutCharacters() {
        let stroke = Keystroke.decode(keyCode: 6, characters: "y", modifiers: [.command, .shift, .option, .control], includesTyping: false)
        XCTAssertEqual(stroke?.keycaps, ["Hyper", "Y"])
    }
    func testShortcutModeDoesNotExposeTypingOrShiftTyping() {
        XCTAssertNil(Keystroke.decode(keyCode: 0, characters: "a", modifiers: [], includesTyping: false))
        XCTAssertNil(Keystroke.decode(keyCode: 0, characters: "A", modifiers: .shift, includesTyping: false))
        XCTAssertNil(Keystroke.decode(keyCode: 36, characters: "\r", modifiers: [], includesTyping: false))
    }
    func testTypingAndSpecialKeys() {
        XCTAssertEqual(Keystroke.decode(keyCode: 0, characters: "é", modifiers: [], includesTyping: true)?.key, "É")
        XCTAssertEqual(Keystroke.decode(keyCode: 123, characters: nil, modifiers: .command, includesTyping: false)?.keycaps, ["⌘", "←"])
        XCTAssertEqual(Keystroke.decode(keyCode: 49, characters: " ", modifiers: [], includesTyping: true)?.key, "space")
        XCTAssertEqual(Keystroke.decode(keyCode: 122, characters: nil, modifiers: [], includesTyping: true)?.key, "F1")
    }
    func testUnknownAndControlCharactersAreDropped() {
        XCTAssertNil(Keystroke.decode(keyCode: 999, characters: nil, modifiers: .command, includesTyping: true))
        XCTAssertNil(Keystroke.decode(keyCode: 0, characters: "\u{01}", modifiers: .command, includesTyping: true))
    }
    func testRepeatedShortcutsCoalesceButSeparateAfterPause() {
        var history = CastHistory()
        let copy = Keystroke(key: "C", modifiers: .command)
        history.append(copy, at: 0)
        history.append(copy, at: 0.2)
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries[0].count, 2)
        history.append(copy, at: 1)
        XCTAssertEqual(history.entries.count, 2)
        XCTAssertEqual(history.entries[1].count, 1)
    }
    func testHistoryIsBoundedAndClears() {
        var history = CastHistory()
        for n in 0..<50 { history.append(Keystroke(key: "\(n)"), at: Double(n)) }
        XCTAssertEqual(history.entries.count, 4)
        XCTAssertEqual(history.entries.first?.stroke.key, "46")
        history.clear()
        XCTAssertTrue(history.entries.isEmpty)
    }
}
