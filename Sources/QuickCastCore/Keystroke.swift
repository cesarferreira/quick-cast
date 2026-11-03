import Foundation

public struct Modifiers: OptionSet, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let control = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let shift = Self(rawValue: 1 << 2)
    public static let command = Self(rawValue: 1 << 3)
    public static let function = Self(rawValue: 1 << 4)
    public static let hyper: Self = [.control, .option, .shift, .command]
    public var isShortcut: Bool { !intersection([.control, .option, .command]).isEmpty }
    public var symbols: [String] {
        if contains(.hyper) { return (contains(.function) ? ["fn"] : []) + ["Hyper"] }
        return [(Self.function, "fn"), (.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            .compactMap { contains($0.0) ? $0.1 : nil }
    }
}

public struct Keystroke: Equatable, Sendable {
    public let key: String
    public let modifiers: Modifiers
    public var keycaps: [String] { modifiers.symbols + (key.isEmpty ? [] : [key]) }
    public var label: String { keycaps.joined() }
    public init(key: String, modifiers: Modifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    /// The key code handles non-printable keys; characters come from the active keyboard layout.
    public static func decode(keyCode: UInt16, characters: String?, modifiers: Modifiers,
                              includesTyping: Bool) -> Self? {
        let special: [UInt16: String] = [
            36: "↵", 48: "⇥", 49: "space", 51: "⌫", 53: "esc", 71: "clear",
            76: "⌤", 115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18",
            80: "F19", 90: "F20"
        ]
        // Shortcut mode intentionally excludes navigation and typing without command/option/control.
        guard includesTyping || modifiers.isShortcut else { return nil }
        if let key = special[keyCode] { return Self(key: key, modifiers: modifiers) }
        guard let characters, !characters.isEmpty,
              characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && !($0.value >= 0xF700 && $0.value <= 0xF8FF) })
        else { return nil }
        // Keep each event compact, including unusual keyboard layouts and composed characters.
        return Self(key: String(characters.prefix(4)).uppercased(), modifiers: modifiers)
    }
}

public struct CastEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let stroke: Keystroke
    public var count: Int
    public var time: TimeInterval
    public init(stroke: Keystroke, time: TimeInterval) {
        id = UUID()
        self.stroke = stroke
        self.time = time
        count = 1
    }
}

public struct CastHistory: Sendable {
    public private(set) var entries: [CastEntry] = []
    public init() {}
    public mutating func append(_ stroke: Keystroke, at time: TimeInterval) {
        if let last = entries.last, last.stroke == stroke, time >= last.time, time - last.time < 0.65 {
            entries[entries.count - 1].count += 1
            entries[entries.count - 1].time = time
        } else if let last = entries.last, last.stroke.key.isEmpty,
                  last.stroke.modifiers.isSubset(of: stroke.modifiers), time >= last.time {
            // A held modifier preview becomes the completed chord instead of a separate history item.
            entries[entries.count - 1] = CastEntry(stroke: stroke, time: time)
        } else {
            entries.append(CastEntry(stroke: stroke, time: time))
            entries = Array(entries.suffix(4))
        }
    }
    public mutating func clear() { entries.removeAll() }
}
