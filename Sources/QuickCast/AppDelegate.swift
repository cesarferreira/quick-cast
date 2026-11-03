import AppKit
import SwiftUI
import Carbon
import QuickCastCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private let model = CastModel()
    private let preview = CastModel()
    private let monitor = KeyboardMonitor()
    private var overlay: OverlayController!
    private var statusItem: NSStatusItem!
    private var welcome: NSWindow?
    private var permissionTimer: Timer?
    private var demoTimer: Timer?
    private var pendingModifier: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlay = OverlayController(model: model, settings: settings)
        preview.push(Keystroke(key: "P", modifiers: [.command, .shift]))
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Quick Cast")
        statusItem.button?.toolTip = "Quick Cast — keystroke overlay"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        monitor.onKey = { [weak self] code, characters, modifiers in
            guard let self else { return }
            self.pendingModifier?.cancel()
            if code == 40 && modifiers == [.control, .option, .command] {
                self.togglePause()
                return
            }
            guard !self.model.paused, !self.model.secureInput,
                  let stroke = Keystroke.decode(keyCode: code, characters: characters, modifiers: modifiers,
                                                includesTyping: self.settings.includesTyping) else { return }
            self.demoTimer?.invalidate()
            self.model.push(stroke)
            self.overlay.show()
        }
        monitor.onModifierPress = { [weak self] stroke in
            guard let self, self.model.status.isCasting else { return }
            self.pendingModifier?.cancel()
            // Remappers may press Hyper's four modifiers separately; show the settled chord.
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.model.status.isCasting, !IsSecureEventInputEnabled() else { return }
                self.demoTimer?.invalidate()
                self.model.push(stroke)
                self.overlay.show()
            }
            self.pendingModifier = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: work)
        }
        model.paused = !(UserDefaults.standard.object(forKey: "castingEnabled") as? Bool ?? true)
        checkState(forceReconnect: true)
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in self?.checkState() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--demo") {
            showWelcome()
            playDemo()
        } else if !UserDefaults.standard.bool(forKey: "welcomed") || !model.connected {
            showWelcome()
        }
        UserDefaults.standard.set(true, forKey: "welcomed")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        checkState(forceReconnect: true)
        showWelcome()
        return true
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        checkState(forceReconnect: true)
    }
    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        pendingModifier?.cancel()
        permissionTimer?.invalidate()
        demoTimer?.invalidate()
        overlay.hide()
    }

    private func connect() {
        model.connected = monitor.start()
        updateStatus()
    }
    private func checkState(forceReconnect: Bool = false) {
        let secure = IsSecureEventInputEnabled()
        if secure != model.secureInput {
            monitor.resetHeldKeys()
            if secure { stopDemoAndHide() }
        }
        model.secureInput = secure
        let granted = monitor.hasPermission
        let previous = model.permissionGranted
        model.permissionGranted = granted
        if !granted && monitor.isRunning {
            monitor.stop()
            stopDemoAndHide()
        }
        let wasConnected = model.connected
        model.connected = monitor.isRunning
        if wasConnected && !model.connected { stopDemoAndHide() }
        if CaptureStatus.shouldReconnect(permissionGranted: granted, previouslyGranted: previous,
                                          connected: model.connected, force: forceReconnect) {
            connect()
        }
        updateStatus()
    }
    private func updateStatus() {
        guard statusItem != nil else { return }
        let status = model.status
        let symbol = status.isCasting ? "record.circle.fill" : (model.paused ? "pause.circle" : "record.circle")
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Quick Cast")
        statusItem.button?.title = status.isCasting ? " ON" : " OFF"
        statusItem.button?.contentTintColor = status.isCasting ? .systemGreen : .secondaryLabelColor
        statusItem.button?.toolTip = "Quick Cast — " + stateTitle
        statusItem.button?.setAccessibilityLabel("Quick Cast — " + stateTitle)
    }
    private var stateTitle: String {
        model.status.title + (model.status.isCasting ? (settings.includesTyping ? " · all keys" : " · shortcuts only") : "")
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let header = NSMenuItem(title: "Quick Cast", action: nil, keyEquivalent: "")
        menu.addItem(header)
        let status = NSMenuItem(title: stateTitle, action: nil, keyEquivalent: "")
        menu.addItem(status)
        menu.addItem(.separator())
        let pause = item(model.paused ? "Resume casting" : "Pause casting", #selector(pauseAction))
        pause.keyEquivalent = "k"
        pause.keyEquivalentModifierMask = [.control, .option, .command]
        menu.addItem(pause)
        menu.addItem(item("Play a preview", #selector(demoAction)))
        menu.addItem(.separator())
        let mode = NSMenu()
        for (title, enabled) in [("Shortcuts only", false), ("All keys, including typing", true)] {
            let option = item(title, #selector(modeAction))
            option.representedObject = enabled
            option.state = settings.includesTyping == enabled ? .on : .off
            mode.addItem(option)
        }
        submenu("Show", mode, in: menu)
        let position = NSMenu()
        for value in Position.allCases {
            let option = item(value.title, #selector(positionAction))
            option.representedObject = value.rawValue
            option.state = settings.position == value ? .on : .off
            position.addItem(option)
        }
        submenu("Position", position, in: menu)
        let size = NSMenu()
        for value in [0.8, 1.0, 1.25] {
            let option = item("\(Int(value * 100))%", #selector(sizeAction))
            option.representedObject = value
            option.state = settings.size == value ? .on : .off
            size.addItem(option)
        }
        submenu("Size", size, in: menu)
        let duration = NSMenu()
        for value in [1.0, 2.0, 3.0] {
            let option = item("\(Int(value)) second\(value == 1 ? "" : "s")", #selector(durationAction))
            option.representedObject = value
            option.state = settings.duration == value ? .on : .off
            duration.addItem(option)
        }
        submenu("Fade after", duration, in: menu)
        let accent = NSMenu()
        for value in Accent.allCases {
            let option = item(value.title, #selector(accentAction))
            option.representedObject = value.rawValue
            option.state = settings.accent == value ? .on : .off
            accent.addItem(option)
        }
        submenu("Accent", accent, in: menu)
        let history = item("Show recent shortcuts", #selector(historyAction))
        history.state = settings.showHistory ? .on : .off
        menu.addItem(history)
        menu.addItem(.separator())
        let welcome = item("Settings & help…", #selector(welcomeAction))
        welcome.keyEquivalent = ","
        menu.addItem(welcome)
        if !model.permissionGranted { menu.addItem(item("Enable Input Monitoring…", #selector(permissionAction))) }
        if !model.connected { menu.addItem(item("Recheck connection", #selector(recheckAction))) }
        menu.addItem(.separator())
        let quit = item("Quit Quick Cast", #selector(quitAction))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }
    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }
    private func submenu(_ title: String, _ submenu: NSMenu, in menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }

    private func stopDemoAndHide() {
        pendingModifier?.cancel()
        demoTimer?.invalidate()
        demoTimer = nil
        overlay.hide()
    }
    private func togglePause() {
        model.paused.toggle()
        UserDefaults.standard.set(!model.paused, forKey: "castingEnabled")
        stopDemoAndHide()
        updateStatus()
    }
    @objc private func pauseAction() { togglePause() }
    @objc private func demoAction() { playDemo() }
    @objc private func welcomeAction() { showWelcome() }
    @objc private func quitAction() { NSApp.terminate(nil) }
    @objc private func screenChanged() { stopDemoAndHide() }
    @objc private func modeAction(_ sender: NSMenuItem) {
        settings.includesTyping = sender.representedObject as? Bool ?? false
        stopDemoAndHide()
        updateStatus()
    }
    @objc private func positionAction(_ sender: NSMenuItem) {
        settings.position = Position(rawValue: sender.representedObject as? String ?? "") ?? .bottomCenter
        playDemo()
    }
    @objc private func sizeAction(_ sender: NSMenuItem) {
        settings.size = sender.representedObject as? Double ?? 1
        playDemo()
    }
    @objc private func durationAction(_ sender: NSMenuItem) {
        settings.duration = sender.representedObject as? Double ?? 2
        playDemo()
    }
    @objc private func accentAction(_ sender: NSMenuItem) {
        settings.accent = Accent(rawValue: sender.representedObject as? String ?? "") ?? .mint
        playDemo()
    }
    @objc private func historyAction() { settings.showHistory.toggle(); playDemo() }
    @objc private func permissionAction() {
        checkState(forceReconnect: true)
        if model.permissionGranted { return }
        CGRequestListenEventAccess()
        checkState(forceReconnect: true)
        if model.permissionGranted { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func recheckAction() { checkState(forceReconnect: true) }

    private func showCustomization() {
        guard let host = welcome?.contentView else { return }
        let menu = NSMenu()
        menu.delegate = self
        menu.popUp(positioning: nil, at: NSPoint(x: host.bounds.width - 250, y: host.bounds.height - 80), in: host)
    }

    private func showWelcome() {
        if welcome == nil {
            let view = WelcomeView(model: model, preview: preview, settings: settings,
                                   enable: { [weak self] in self?.permissionAction() },
                                   demo: { [weak self] in self?.playDemo() },
                                   toggleCasting: { [weak self] in self?.togglePause() },
                                   recheck: { [weak self] in self?.checkState(forceReconnect: true) },
                                   customize: { [weak self] in self?.showCustomization() })
            let host = NSHostingView(rootView: view)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: host.fittingSize.height),
                                  styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "Quick Cast"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.center()
            welcome = window
        }
        welcome?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func playDemo() {
        stopDemoAndHide()
        let sequence = [Keystroke(key: "", modifiers: [.control, .option, .shift, .command]), Keystroke(key: "P", modifiers: [.command, .shift]),
                        Keystroke(key: "→", modifiers: .option), Keystroke(key: "C", modifiers: .command),
                        Keystroke(key: "V", modifiers: .command)]
        var index = 0
        let advance = { [weak self] in
            guard let self else { return }
            guard !self.model.secureInput else { self.stopDemoAndHide(); return }
            guard index < sequence.count else { self.demoTimer?.invalidate(); self.demoTimer = nil; return }
            self.preview.push(sequence[index])
            self.model.push(sequence[index])
            self.overlay.show()
            index += 1
        }
        advance()
        demoTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { _ in advance() }
    }
}
