import XCTest
@testable import QuickCastCore

final class KiwiHyperTests: XCTestCase {
    func testRecognizesTheActualHidutilCapsToF18Mapping() {
        let mapping = "( { HIDKeyboardModifierMappingDst = 30064771181; HIDKeyboardModifierMappingSrc = 30064771129; } )"
        XCTAssertTrue(KiwiHyperTracker.matchesHIDMapping(Data(mapping.utf8)))
        XCTAssertFalse(KiwiHyperTracker.matchesHIDMapping(Data("( { HIDKeyboardModifierMappingDst = 30064771130; HIDKeyboardModifierMappingSrc = 30064771129; } )".utf8)))
        XCTAssertFalse(KiwiHyperTracker.matchesHIDMapping(Data("( )".utf8)))
    }
    func testKiwiF18SourceIsHyperEvenWhenEventOnlyHasShift() {
        var tracker = KiwiHyperTracker()
        XCTAssertTrue(tracker.update(keyCode: 79, isDown: true, enabled: true))
        XCTAssertEqual(tracker.modifiers(physical: .shift), [.control, .option, .shift, .command])
        XCTAssertEqual(Keystroke(key: "", modifiers: tracker.modifiers(physical: .shift)).keycaps, ["Hyper"])
    }
    func testConsumedHyperBindingStillGetsTheHyperLabel() {
        var tracker = KiwiHyperTracker()
        _ = tracker.update(keyCode: 79, isDown: true, enabled: true)
        XCTAssertEqual(Keystroke(key: "T", modifiers: tracker.modifiers(physical: [])).keycaps, ["Hyper", "T"])
        XCTAssertTrue(tracker.update(keyCode: 79, isDown: false, enabled: true))
        XCTAssertEqual(tracker.modifiers(physical: .shift), .shift)
    }
    func testOrdinaryF18IsNotHyperWithoutKiwiMapping() {
        var tracker = KiwiHyperTracker()
        XCTAssertFalse(tracker.update(keyCode: 79, isDown: true, enabled: false))
        XCTAssertFalse(tracker.isHeld)
        XCTAssertEqual(tracker.modifiers(physical: .shift), .shift)
    }
    func testOtherKeysDoNotReleaseHyper() {
        var tracker = KiwiHyperTracker()
        _ = tracker.update(keyCode: 79, isDown: true, enabled: true)
        XCTAssertFalse(tracker.update(keyCode: 17, isDown: false, enabled: true))
        XCTAssertTrue(tracker.isHeld)
    }
}
