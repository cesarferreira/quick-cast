import Foundation

/// Kiwi consumes its Caps Lock → F18 source before the normal session event stream.
public struct KiwiHyperTracker: Sendable {
    public private(set) var isHeld = false
    public init() {}
    public mutating func update(keyCode: UInt16, isDown: Bool, enabled: Bool) -> Bool {
        guard enabled, keyCode == 79 else { return false }
        isHeld = isDown
        return true
    }
    public func modifiers(physical: Modifiers) -> Modifiers {
        isHeld ? physical.union(.hyper) : physical
    }
    public static func matchesHIDMapping(_ data: Data) -> Bool {
        guard let rows = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [[String: Any]] else { return false }
        return rows.contains { row in
            usage(row["HIDKeyboardModifierMappingSrc"]) == 0x700000039 &&
            usage(row["HIDKeyboardModifierMappingDst"]) == 0x70000006D
        }
    }
    private static func usage(_ value: Any?) -> UInt64? {
        if let number = value as? NSNumber { return number.uint64Value }
        guard let string = value as? String else { return nil }
        return string.hasPrefix("0x") ? UInt64(string.dropFirst(2), radix: 16) : UInt64(string)
    }
}
