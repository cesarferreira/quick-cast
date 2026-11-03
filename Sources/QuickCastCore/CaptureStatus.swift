public enum CaptureStatus: Equatable, Sendable {
    case casting, paused, permissionRequired, reconnectRequired, secureInput

    public static func shouldReconnect(permissionGranted: Bool, previouslyGranted: Bool, connected: Bool, force: Bool) -> Bool {
        permissionGranted && !connected && (force || !previouslyGranted)
    }

    public static func resolve(permissionGranted: Bool, connected: Bool, paused: Bool, secureInput: Bool) -> Self {
        if !connected { return permissionGranted ? .reconnectRequired : .permissionRequired }
        if paused { return .paused }
        if secureInput { return .secureInput }
        return .casting
    }

    public var isCasting: Bool { self == .casting }
    public var title: String {
        switch self {
        case .casting: return "Casting is ON"
        case .paused: return "Casting is OFF — paused"
        case .permissionRequired: return "Casting is OFF — access needed"
        case .reconnectRequired: return "Casting is OFF — reconnect needed"
        case .secureInput: return "Casting is hidden — protected input"
        }
    }
}
