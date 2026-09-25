import AppKit
import SwiftUI
import ServiceManagement

/// Chiavi di UserDefaults per le preferenze di visualizzazione.
enum Prefs {
    static let leftEar = "leftEar"
    static let rightEar = "rightEar"
    static let showSession = "showSession"
    static let showWeek = "showWeek"
    static let showModelLimits = "showModelLimits"
    static let showTokens = "showTokens"
    static let showModels = "showModels"
    static let alertSound = "alertSound"
}

/// Cosa mostrare in ciascuna delle due "orecchie" del notch chiuso.
enum EarContent: String, CaseIterable, Identifiable {
    case session, week, todayTokens, weekTokens, topModel, none
    var id: String { rawValue }

    var title: String {
        switch self {
        case .session: "Sessione (5h)"
        case .week: "Settimana"
        case .todayTokens: "Token di oggi"
        case .weekTokens: "Token della settimana"
        case .topModel: "Modello più usato"
        case .none: "Niente"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @AppStorage(Prefs.leftEar) private var leftEar = EarContent.session
    @AppStorage(Prefs.rightEar) private var rightEar = EarContent.week
    @AppStorage(Prefs.showSession) private var showSession = true
    @AppStorage(Prefs.showWeek) private var showWeek = true
    @AppStorage(Prefs.showModelLimits) private var showModelLimits = true
    @AppStorage(Prefs.showTokens) private var showTokens = true
    @AppStorage(Prefs.showModels) private var showModels = true
    @AppStorage(SessionWatcher.enabledKey) private var alerts = true
    @AppStorage(Prefs.alertSound) private var alertSound = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Impostazioni").font(.system(size: 20, weight: .bold))
                    Text("Scegli cosa vedere nel notch").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            NotchPreview(left: leftEar, right: rightEar, store: store)

            GlassSection("Notch chiuso") {
                PickerRow(icon: "arrow.left.to.line", title: "Lato sinistro", selection: $leftEar)
                RowDivider()
                PickerRow(icon: "arrow.right.to.line", title: "Lato destro", selection: $rightEar)
            }

            GlassSection("Pannello aperto") {
                ToggleRow(icon: "timer", tint: .green, title: "Sessione (5h)", isOn: $showSession)
                RowDivider()
                ToggleRow(icon: "calendar", tint: .yellow, title: "Settimana", isOn: $showWeek)
                RowDivider()
                ToggleRow(icon: "square.stack.3d.up", tint: .purple, title: "Limiti per modello (Opus, Sonnet)", isOn: $showModelLimits)
                RowDivider()
                ToggleRow(icon: "number", tint: claudeOrange, title: "Token di oggi e della settimana", isOn: $showTokens)
                RowDivider()
                ToggleRow(icon: "cpu", tint: .blue, title: "Modelli della settimana", isOn: $showModels)
            }

            GlassSection("Generale") {
                ToggleRow(icon: "power", tint: .gray, title: "Avvia al login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
                RowDivider()
                ToggleRow(icon: "bell.fill", tint: .red, title: "Avviso quando una sessione finisce", isOn: $alerts)
                RowDivider()
                ToggleRow(icon: "speaker.wave.2.fill", tint: .pink, title: "Suono dell'avviso", isOn: $alertSound)
                    .disabled(!alerts)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 34) // spazio per i semafori della finestra
        .padding(.bottom, 22)
        .frame(width: 460)
        .tint(claudeOrange)
    }
}

/// Anteprima dal vivo del notch chiuso con le scelte correnti.
private struct NotchPreview: View {
    let left: EarContent
    let right: EarContent
    @ObservedObject var store: UsageStore
    @State private var sideWidth = NotchState.minSideWidth

    var body: some View {
        EarsRow(left: left, right: right, store: store, notchWidth: 130, sideWidth: $sideWidth)
        .foregroundStyle(.white)
        .frame(height: 32)
        .background(NotchShape(bottomRadius: 12).fill(.black))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [Color(red: 0.36, green: 0.49, blue: 1), Color(red: 0.79, green: 0.31, blue: 0.71), Color(red: 1, green: 0.6, blue: 0.29)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(0.85),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: left)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: right)
    }
}

private struct GlassSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
            VStack(spacing: 0) { content }
                .padding(.horizontal, 12)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.primary.opacity(0.08)))
        }
    }
}

private struct RowIcon: View {
    let name: String
    let tint: Color
    var body: some View {
        Image(systemName: name)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct ToggleRow: View {
    let icon: String
    let tint: Color
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 10) {
            RowIcon(name: icon, tint: tint)
            Text(title).font(.system(size: 13))
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
        .padding(.vertical, 9)
    }
}

private struct PickerRow: View {
    let icon: String
    let title: String
    @Binding var selection: EarContent
    var body: some View {
        HStack(spacing: 10) {
            RowIcon(name: icon, tint: claudeOrange)
            Text(title).font(.system(size: 13))
            Spacer()
            Picker("", selection: $selection) {
                ForEach(EarContent.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 190)
        }
        .padding(.vertical, 7)
    }
}

private struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 34).opacity(0.6) }
}

/// Finestra delle impostazioni, riusata a ogni apertura. Su macOS 26 lo sfondo è Liquid Glass.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(store: UsageStore) {
        if window == nil {
            let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.title = "Impostazioni ClaudeNotch"
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false

            let hosting = NSHostingView(rootView: SettingsView(store: store))
            let size = hosting.fittingSize
            if #available(macOS 26.0, *) {
                // Finestra trasparente: la forma e l'ombra le dà il vetro.
                w.isOpaque = false
                w.backgroundColor = .clear
                let glass = NSGlassEffectView()
                glass.cornerRadius = 26
                // Un velo del colore della finestra: resta vetro ma il testo dietro non disturba.
                glass.tintColor = NSColor.windowBackgroundColor.withAlphaComponent(0.55)
                glass.contentView = hosting
                w.contentView = glass
            } else {
                let blur = NSVisualEffectView()
                blur.material = .sidebar
                blur.blendingMode = .behindWindow
                blur.state = .active
                hosting.translatesAutoresizingMaskIntoConstraints = false
                blur.addSubview(hosting)
                NSLayoutConstraint.activate([
                    hosting.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
                    hosting.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
                    hosting.topAnchor.constraint(equalTo: blur.topAnchor),
                    hosting.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
                ])
                w.contentView = blur
            }
            w.setContentSize(size)
            w.center()
            window = w
        }
        // L'app non ha icona nel Dock: va attivata per portare la finestra in primo piano.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
