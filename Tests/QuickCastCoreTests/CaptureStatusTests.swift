import XCTest
@testable import QuickCastCore

final class CaptureStatusTests: XCTestCase {
    func testAccessGrantedOutsideTheAppStartsCaptureWithoutAnotherButtonClick() {
        XCTAssertTrue(CaptureStatus.shouldReconnect(permissionGranted: true, previouslyGranted: false, connected: false, force: false))
        XCTAssertFalse(CaptureStatus.shouldReconnect(permissionGranted: false, previouslyGranted: false, connected: false, force: false))
    }
    func testConnectionFailuresDoNotRetryEveryTimerTick() {
        XCTAssertFalse(CaptureStatus.shouldReconnect(permissionGranted: true, previouslyGranted: true, connected: false, force: false))
        XCTAssertTrue(CaptureStatus.shouldReconnect(permissionGranted: true, previouslyGranted: true, connected: false, force: true))
        XCTAssertFalse(CaptureStatus.shouldReconnect(permissionGranted: true, previouslyGranted: true, connected: true, force: true))
    }
    func testGrantedPermissionWithFailedConnectionDoesNotAskForPermissionAgain() {
        XCTAssertEqual(CaptureStatus.resolve(permissionGranted: true, connected: false, paused: false, secureInput: false), .reconnectRequired)
    }
    func testMissingPermissionIsDistinctFromPaused() {
        XCTAssertEqual(CaptureStatus.resolve(permissionGranted: false, connected: false, paused: false, secureInput: false), .permissionRequired)
        XCTAssertEqual(CaptureStatus.resolve(permissionGranted: true, connected: true, paused: true, secureInput: false), .paused)
    }
    func testOnlyConnectedUnpausedCaptureIsOn() {
        XCTAssertEqual(CaptureStatus.resolve(permissionGranted: true, connected: true, paused: false, secureInput: false), .casting)
        XCTAssertEqual(CaptureStatus.resolve(permissionGranted: true, connected: true, paused: false, secureInput: true), .secureInput)
    }
}
