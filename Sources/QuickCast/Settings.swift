import AppKit
import SwiftUI

final class Settings: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var includesTyping: Bool { didSet { defaults.set(includesTyping, forKey: "includesTyping") } }
    @Published var position: Position { didSet { defaults.set(position.rawValue, forKey: "position") } }
    @Published var size: Double { didSet { defaults.set(size, forKey: "size") } }
    @Published var duration: Double { didSet { defaults.set(duration, forKey: "duration") } }
    @Published var accent: Accent { didSet { defaults.set(accent.rawValue, forKey: "accent") } }
    @Published var showHistory: Bool { didSet { defaults.set(showHistory, forKey: "showHistory") } }

    init() {
        includesTyping = defaults.bool(forKey: "includesTyping")
        position = Position(rawValue: defaults.string(forKey: "position") ?? "") ?? .bottomCenter
        let savedSize = defaults.double(forKey: "size")
        size = [0.8, 1.0, 1.25].contains(savedSize) ? savedSize : 1
        let savedDuration = defaults.double(forKey: "duration")
        duration = [1.0, 2.0, 3.0].contains(savedDuration) ? savedDuration : 2
        accent = Accent(rawValue: defaults.string(forKey: "accent") ?? "") ?? .mint
        showHistory = defaults.object(forKey: "showHistory") as? Bool ?? true
    }
}

enum Position: String, CaseIterable {
    case bottomLeft, bottomCenter, bottomRight, topLeft, topCenter, topRight
    var title: String {
        switch self {
        case .bottomLeft: return "Bottom left"
        case .bottomCenter: return "Bottom center"
        case .bottomRight: return "Bottom right"
        case .topLeft: return "Top left"
        case .topCenter: return "Top center"
        case .topRight: return "Top right"
        }
    }
    func origin(in screen: CGRect, size: CGSize) -> CGPoint {
        let margin: CGFloat = 28
        let x: CGFloat
        switch self {
        case .bottomLeft, .topLeft: x = screen.minX + margin
        case .bottomRight, .topRight: x = screen.maxX - size.width - margin
        default: x = screen.midX - size.width / 2
        }
        let top = [Self.topLeft, .topCenter, .topRight].contains(self)
        return CGPoint(x: max(screen.minX, x), y: top ? screen.maxY - size.height - margin : screen.minY + margin)
    }
}

enum Accent: String, CaseIterable {
    case mint, lilac, peach
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .mint: return Color(red: 0.57, green: 0.97, blue: 0.77)
        case .lilac: return Color(red: 0.77, green: 0.69, blue: 1)
        case .peach: return Color(red: 1, green: 0.73, blue: 0.57)
        }
    }
}
