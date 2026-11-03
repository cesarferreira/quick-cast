import AppKit
import SwiftUI
import QuickCastCore

final class CastModel: ObservableObject {
    @Published var history = CastHistory()
    @Published var paused = false
    @Published var connected = false
    @Published var secureInput = false
    @Published var permissionGranted = false
    var status: CaptureStatus {
        .resolve(permissionGranted: permissionGranted, connected: connected, paused: paused, secureInput: secureInput)
    }
    func push(_ stroke: Keystroke) {
        history.append(stroke, at: ProcessInfo.processInfo.systemUptime)
    }
    func clear() { history.clear() }
}

struct Glass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct Keycap: View {
    let text: String
    let accent: Color
    var primary = false
    var body: some View {
        Text(text)
            .font(.system(size: text.count > 2 ? 22 : 32, weight: .medium, design: .rounded))
            .foregroundStyle(primary ? Color.black.opacity(0.88) : .white.opacity(0.94))
            .frame(minWidth: text.count > 2 ? 72 : 54, minHeight: 56)
            .padding(.horizontal, text.count > 2 ? 10 : 2)
            .background {
                ZStack {
                    if primary {
                        accent
                    } else {
                        Glass()
                        Color(red: 0.08, green: 0.09, blue: 0.1).opacity(0.85)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.32), radius: 8, y: 4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(primary ? 0.35 : 0.15), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1).fill(.black.opacity(0.12)).frame(height: 2).padding(.horizontal, 10).padding(.bottom, 4)
            }
            .accessibilityLabel(text)
    }
}

struct HUDView: View {
    @ObservedObject var model: CastModel
    @ObservedObject var settings: Settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static func width(for entry: CastEntry?) -> CGFloat {
        guard let entry else { return 168 }
        let keys = entry.stroke.keycaps
        let keyWidths = keys.reduce(CGFloat(0)) { $0 + ($1.count > 2 ? 92 : 58) }
        return max(168, keyWidths + CGFloat(max(0, keys.count - 1)) * 8 + (entry.count > 1 ? 48 : 0) + 44)
    }
    var body: some View {
        let entry = model.history.entries.last
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if let entry {
                    ForEach(Array(entry.stroke.keycaps.enumerated()), id: \.offset) { index, key in
                        Keycap(text: key, accent: settings.accent.color, primary: index == entry.stroke.keycaps.count - 1)
                    }
                    if entry.count > 1 {
                        Text("×\(entry.count)").font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(settings.accent.color).padding(.leading, 4)
                            .contentTransition(.numericText())
                    }
                } else {
                    Keycap(text: "⌘", accent: settings.accent.color)
                    Keycap(text: "K", accent: settings.accent.color, primary: true)
                }
            }
            .id(entry?.id)
            .transition(.asymmetric(insertion: .offset(y: reduceMotion ? 0 : 7).combined(with: .opacity), removal: .opacity))
            .frame(height: 58)
            if settings.showHistory {
                HStack(spacing: 10) {
                    let previous = Array(model.history.entries.dropLast().suffix(3))
                    ForEach(previous) { item in
                        Text(item.stroke.label + (item.count > 1 ? " ×\(item.count)" : ""))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.9), radius: 3, y: 1)
                            .lineLimit(1)
                        if item.id != previous.last?.id {
                            Circle().fill(.white.opacity(0.5)).frame(width: 2, height: 2)
                        }
                    }
                }.frame(height: 13)
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 8)
        .frame(width: Self.width(for: entry))
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: model.history.entries)
        .preferredColorScheme(.dark)
    }
}

final class OverlayController {
    private let panel: NSPanel
    private let model: CastModel
    private let settings: Settings
    private var hideWork: DispatchWorkItem?
    private var generation = 0
    private var activeScreen: NSScreen?

    init(model: CastModel, settings: Settings) {
        self.model = model
        self.settings = settings
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: AnyView(HUDView(model: model, settings: settings).padding(24)))
    }

    func show() {
        hideWork?.cancel()
        generation += 1
        let wasHidden = !panel.isVisible || panel.alphaValue < 0.01
        if wasHidden {
            activeScreen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        }
        reposition()
        panel.orderFrontRegardless()
        // Reset immediately to avoid an old fade animation hiding a new shortcut.
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 1
        }
        let token = generation
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == token else { return }
            self.fade(token: token)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.duration, execute: work)
    }

    func reposition() {
        guard let screen = activeScreen ?? NSScreen.main else { return }
        let baseWidth = HUDView.width(for: model.history.entries.last) + 48
        let baseHeight: CGFloat = settings.showHistory ? 149 : 122
        let size = NSSize(width: baseWidth * settings.size, height: baseHeight * settings.size)
        if let host = panel.contentView as? NSHostingView<AnyView> {
            host.rootView = AnyView(
                HUDView(model: model, settings: settings).padding(24)
                    .frame(width: baseWidth, height: baseHeight)
                    .scaleEffect(settings.size)
                    .frame(width: size.width, height: size.height)
            )
        }
        panel.setFrame(NSRect(origin: settings.position.origin(in: screen.visibleFrame, size: size), size: size), display: true)
    }

    func hide() {
        generation += 1
        hideWork?.cancel()
        panel.alphaValue = 0
        panel.orderOut(nil)
        model.clear()
    }

    private func fade(token: Int) {
        let duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.25
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            guard let self, self.generation == token else { return }
            self.panel.orderOut(nil)
            self.model.clear()
        }
    }
}
