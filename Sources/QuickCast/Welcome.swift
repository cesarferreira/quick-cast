import SwiftUI

struct WelcomeView: View {
    @ObservedObject var model: CastModel
    @ObservedObject var preview: CastModel
    @ObservedObject var settings: Settings
    var enable: () -> Void
    var demo: () -> Void
    var toggleCasting: () -> Void
    var recheck: () -> Void
    var customize: () -> Void

    private var status: String {
        switch model.status {
        case .casting:
            return settings.includesTyping ? "All keys appear live, including typing." : "Shortcuts appear live. Regular typing stays hidden."
        case .paused:
            return "Your keys are hidden. Resume whenever you're ready."
        case .secureInput:
            return "macOS is protecting keyboard input. Casting resumes when protected input ends."
        case .reconnectRequired:
            return "Access is enabled, but capture isn't connected. Try reconnecting, or quit and reopen Quick Cast."
        case .permissionRequired:
            return "Enable Quick Cast in Input Monitoring. Already on? Switch it off and on again, then reopen Quick Cast."
        }
    }
    private var actionTitle: String {
        if model.connected { return model.paused ? "Resume casting" : "Pause casting" }
        return model.permissionGranted ? "Reconnect" : "Enable access"
    }
    private var stateColor: Color {
        model.status.isCasting ? settings.accent.color : (model.connected ? .orange : .white.opacity(0.45))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "keyboard").font(.system(size: 17, weight: .medium)).foregroundStyle(settings.accent.color)
                Text("quick cast").font(.system(size: 16, weight: .semibold, design: .rounded)).tracking(-0.4)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(stateColor).frame(width: 6, height: 6)
                    Text(model.status.isCasting ? "ON" : "OFF")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(stateColor)
                }.accessibilityLabel(model.status.title)
                Toggle("Casting", isOn: Binding(
                    get: { model.connected && !model.paused },
                    set: { enabled in
                        if enabled != !model.paused { toggleCasting() }
                    }
                ))
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
                .disabled(!model.connected)
                .accessibilityLabel("Casting enabled")
                .help(model.connected ? "Turn casting on or off" : "Connect keyboard capture to turn casting on")
                Button(action: customize) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16)).foregroundStyle(.white.opacity(0.5))
                }.buttonStyle(.plain).help("Customize Quick Cast").accessibilityLabel("Customize Quick Cast")
            }.padding(.top, 36)
            VStack(spacing: 10) {
                Text("Let your keys\ndo the talking.")
                    .font(.system(size: 43, weight: .semibold, design: .rounded)).tracking(-1.8)
                    .multilineTextAlignment(.center).lineSpacing(-1)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A little clarity for your demos, tutorials, and calls.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
            }.padding(.top, 30)
            HUDView(model: preview, settings: settings)
                .padding(.top, 26).padding(.bottom, 20)
            HStack(spacing: 24) {
                feature("cursorarrow.rays", "Stays out of your way")
                feature("lock", "On-device. No history saved.")
            }.padding(.bottom, 23)
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Circle().fill(stateColor).frame(width: 5, height: 5)
                        Text(model.status.title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text(status).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 310, alignment: .leading)
                }
                Spacer(minLength: 4)
                Button(action: model.connected ? toggleCasting : enable) {
                    HStack(spacing: 7) {
                        Text(actionTitle)
                        Image(systemName: "arrow.right").font(.system(size: 10, weight: .semibold))
                    }.font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 15).padding(.vertical, 12)
                        .foregroundStyle(.black.opacity(0.85))
                        .background(settings.accent.color, in: RoundedRectangle(cornerRadius: 10))
                }.buttonStyle(.plain)
            }.padding(.top, 20)
            if !model.connected {
                Button("Already enabled? Recheck connection", action: recheck)
                    .buttonStyle(.plain).font(.system(size: 10))
                    .foregroundStyle(settings.accent.color.opacity(0.8))
                    .padding(.top, 12)
            }
            HStack(spacing: 5) {
                Text("⌃ ⌥ ⌘ K").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                Text(model.paused ? "to resume  ·" : "to pause  ·").foregroundStyle(.white.opacity(0.3))
                Button("Play a preview", action: demo).buttonStyle(.plain).foregroundStyle(settings.accent.color.opacity(0.8))
                Spacer()
                Text("v1.0").foregroundStyle(.white.opacity(0.2))
            }.font(.system(size: 10)).padding(.top, 20).padding(.bottom, 26)
        }
        .padding(.horizontal, 38)
        .frame(width: 600)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            ZStack {
                Color(red: 0.055, green: 0.065, blue: 0.075)
                RadialGradient(colors: [settings.accent.color.opacity(0.075), .clear], center: .init(x: 0.5, y: 0.35), startRadius: 0, endRadius: 290)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
    private func feature(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(settings.accent.color.opacity(0.7))
            Text(title).foregroundStyle(.white.opacity(0.4))
        }.font(.system(size: 10))
    }
}
