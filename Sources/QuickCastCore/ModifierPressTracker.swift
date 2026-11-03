/// Emits newly pressed modifier combinations, suppressing release-only transitions.
public struct ModifierPressTracker: Sendable {
    private var held: Modifiers = []
    public init() {}
    public mutating func update(_ modifiers: Modifiers) -> Keystroke? {
        let pressed = modifiers.subtracting(held)
        held = modifiers
        guard !pressed.isEmpty else { return nil }
        return Keystroke(key: "", modifiers: modifiers)
    }
}
