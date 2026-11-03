import XCTest
@testable import QuickCastCore

final class ModifierPressTests: XCTestCase {
    private let hyper: Modifiers = [.control, .option, .shift, .command]

    func testHyperUsesOneNamedKeycap() {
        XCTAssertEqual(Keystroke(key: "", modifiers: hyper).keycaps, ["Hyper"])
    }
    func testHyperPressIsDisplayedWithoutARegularKeyDown() {
        var tracker = ModifierPressTracker()
        XCTAssertEqual(tracker.update(hyper), Keystroke(key: "", modifiers: hyper))
    }
    func testReleasingHyperDoesNotDisplayPartialReleaseCombinations() {
        var tracker = ModifierPressTracker()
        _ = tracker.update(hyper)
        XCTAssertNil(tracker.update([.control, .option, .command]))
        XCTAssertNil(tracker.update(.command))
        XCTAssertNil(tracker.update([]))
        XCTAssertEqual(tracker.update(hyper)?.modifiers, hyper)
    }
    func testRepeatedFlagsWithoutANewPressAreIgnored() {
        var tracker = ModifierPressTracker()
        XCTAssertEqual(tracker.update(.command)?.keycaps, ["⌘"])
        XCTAssertNil(tracker.update(.command))
        XCTAssertEqual(tracker.update([.command, .shift])?.keycaps, ["⇧", "⌘"])
    }
    func testAddingAKeyPromotesModifierPreviewIntoTheFullShortcut() {
        var history = CastHistory()
        history.append(Keystroke(key: "", modifiers: hyper), at: 0)
        history.append(Keystroke(key: "P", modifiers: hyper), at: 0.1)
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries.last?.stroke.keycaps, ["Hyper", "P"])
    }
    func testProgressiveModifierPressesProduceOneHistoryEntry() {
        var history = CastHistory()
        history.append(Keystroke(key: "", modifiers: .command), at: 0)
        history.append(Keystroke(key: "", modifiers: [.command, .shift]), at: 0.1)
        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries.last?.stroke.keycaps, ["⇧", "⌘"])
    }
}
