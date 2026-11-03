import AppKit
import Carbon
import QuickCastCore

final class KeyboardMonitor {
    var onModifierPress: ((Keystroke) -> Void)?
    private var modifierTracker = ModifierPressTracker()
    private var kiwiHyper = KiwiHyperTracker()
    private var kiwiMappingEnabled = false
    var onKey: ((UInt16, String?, Modifiers) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var isRunning: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }
    var hasPermission: Bool { CGPreflightListenEventAccess() }

    @discardableResult func start() -> Bool {
        if isRunning { return true }
        stop()
        guard hasPermission else { return false }
        kiwiMappingEnabled = KiwiMapping.isEnabled()
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
                 | (CGEventMask(1) << CGEventType.keyUp.rawValue)
                 | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            // Snapshot before later taps can rewrite or consume this event.
            let flags = event.flags
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let characters = type == .keyDown ? NSEvent(cgEvent: event)?.charactersIgnoringModifiers : nil
            // Keep rendering off the event-tap callback.
            DispatchQueue.main.async { [weak monitor] in
                guard let monitor, monitor.isRunning, !IsSecureEventInputEnabled() else { return }
                var modifiers: Modifiers = []
                if flags.contains(.maskControl) { modifiers.insert(.control) }
                if flags.contains(.maskAlternate) { modifiers.insert(.option) }
                if flags.contains(.maskShift) { modifiers.insert(.shift) }
                if flags.contains(.maskCommand) { modifiers.insert(.command) }
                if type == .keyDown || type == .keyUp,
                   monitor.kiwiHyper.update(keyCode: keyCode, isDown: type == .keyDown,
                                           enabled: monitor.kiwiMappingEnabled) {
                    let combined = monitor.kiwiHyper.modifiers(physical: modifiers)
                    if let stroke = monitor.modifierTracker.update(combined) {
                        monitor.onModifierPress?(stroke)
                    }
                    return
                }
                modifiers = monitor.kiwiHyper.modifiers(physical: modifiers)
                if type == .flagsChanged {
                    if let stroke = monitor.modifierTracker.update(modifiers) {
                        monitor.onModifierPress?(stroke)
                    }
                    return
                }
                guard type == .keyDown else { return }
                monitor.onKey?(keyCode, characters, modifiers)
            }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
                                         options: .listenOnly, eventsOfInterest: mask,
                                         callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return isRunning
    }

    func resetHeldKeys() {
        modifierTracker = ModifierPressTracker()
        kiwiHyper = KiwiHyperTracker()
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
        resetHeldKeys()
    }
    deinit { stop() }
}
