import Foundation
import QuickCastCore

/// Only treat reserved F18 as Hyper when Kiwi and its exact HID mapping are active.
enum KiwiMapping {
    static func isEnabled() -> Bool {
        let probe = Process()
        probe.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        probe.arguments = ["-x", "kiwi"]
        probe.standardOutput = FileHandle.nullDevice
        probe.standardError = FileHandle.nullDevice
        do { try probe.run(); probe.waitUntilExit() } catch { return false }
        guard probe.terminationStatus == 0 else { return false }

        let mapping = Process()
        mapping.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        mapping.arguments = ["property", "--get", "UserKeyMapping"]
        let output = Pipe()
        mapping.standardOutput = output
        mapping.standardError = FileHandle.nullDevice
        do { try mapping.run() } catch { return false }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        mapping.waitUntilExit()
        return mapping.terminationStatus == 0 && KiwiHyperTracker.matchesHIDMapping(data)
    }
}
