import AppKit

let app = NSApplication.shared
// The app is a single menu bar utility, including when its bundle is opened twice.
let running = NSRunningApplication.runningApplications(withBundleIdentifier: "dev.cesar.quickcast")
if let other = running.first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
    other.activate(options: [])
} else {
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
