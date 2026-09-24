import SwiftUI
import ServiceManagement

private let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

private func color(for percent: Double) -> Color {
    switch percent {
    case ..<50: return Color(red: 0.36, green: 0.84, blue: 0.52)
    case ..<80: return Color(red: 1.0, green: 0.78, blue: 0.3)
    default: return Color(red: 1.0, green: 0.38, blue: 0.35)
    }
}

private func formatTokens(_ n: Int) -> String {
    switch n {
    case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
    case 1_000...: return String(format: "%.1fk", Double(n) / 1_000)
    default: return "\(n)"
    }
}

private func countdown(to date: Date?, now: Date) -> String {
    guard let date else { return "—" }
    let s = max(0, Int(date.timeIntervalSince(now)))
    let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
    if d > 0 { return "\(d)g \(h)h" }
    if h > 0 { return "\(h)h \(m)m" }
    return "\(m)m"
}

struct NotchView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var state: NotchState

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                NotchShape(bottomRadius: state.expanded ? 22 : state.alert != nil ? 18 : 10)
                    .fill(Color.black)

                VStack(spacing: 0) {
                    collapsedRow
                        .frame(height: state.notchHeight)
                        .opacity(state.expanded ? 0 : 1) // nascoste da aperto, riappaiono alla chiusura
                    if !state.expanded, let alert = state.alert {
                        AlertContent(alert: alert)
                            .padding(.horizontal, 20)
                            .frame(height: NotchState.alertSize.height, alignment: .center)
                            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                            .id(alert.id)
                    }
                    if state.expanded {
                        ExpandedContent(store: store)
                            .padding(.horizontal, 22)
                            .padding(.bottom, 16)
                            .fixedSize(horizontal: false, vertical: true)
                            .background(GeometryReader { geo in
                                Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                            })
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
                    }
                }
            }
            .frame(width: state.currentSize.width, height: state.currentSize.height)
            .shadow(color: .black.opacity(state.expanded || state.alert != nil ? 0.5 : 0), radius: 12, y: 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .onPreferenceChange(ContentHeightKey.self) { h in
            guard h > 0, abs(h - state.contentHeight) > 0.5 else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { state.contentHeight = h }
        }
    }

    /// Le due "orecchie" ai lati del notch.
    private var collapsedRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(claudeOrange)
                if let s = store.session {
                    Text("\(Int(s.percent.rounded()))%")
                        .foregroundStyle(color(for: s.percent))
                } else if store.error != nil {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                }
            }
            .frame(width: NotchState.sideWidth)

            Spacer(minLength: state.notchWidth)

            HStack(spacing: 5) {
                if let w = store.weekly {
                    Ring(percent: w.percent).frame(width: 12, height: 12)
                    Text("\(Int(w.percent.rounded()))%")
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(width: NotchState.sideWidth)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .frame(width: state.collapsedSize.width)
    }
}

/// Avviso nel notch quando una sessione di Claude Code ha finito.
private struct AlertContent: View {
    let alert: SessionAlert
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color(red: 0.36, green: 0.84, blue: 0.52))
                .scaleEffect(appeared ? 1 : 0.4)
                .animation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.1), value: appeared)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("Sessione conclusa")
                        .foregroundStyle(.secondary)
                    Text(alert.project)
                        .foregroundStyle(claudeOrange)
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)
                Text(alert.title ?? alert.branch ?? "Claude Code ti aspetta")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 8)
            Text(SessionWatcher.format(alert.duration))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .onAppear { appeared = true }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ExpandedContent: View {
    @ObservedObject var store: UsageStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var notifications = SessionWatcher.isEnabled

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            VStack(alignment: .leading, spacing: 12) {
                header

                UsageBar(title: "Sessione (5h)", window: store.session, now: ctx.date)
                UsageBar(title: "Settimana", window: store.weekly, now: ctx.date)
                if let o = store.weeklyOpus { UsageBar(title: "Settimana · Opus", window: o, now: ctx.date) }
                if let s = store.weeklySonnet { UsageBar(title: "Settimana · Sonnet", window: s, now: ctx.date) }

                Divider().overlay(.white.opacity(0.08))

                tokenTable

                if !store.local.models.isEmpty {
                    ModelBreakdown(models: store.local.models)
                }
            }
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("Claude Usage", systemImage: "sparkle")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(claudeOrange)
            Spacer()
            if let e = store.error {
                Text(e).font(.system(size: 10)).foregroundStyle(.yellow)
            } else if let u = store.lastUpdate {
                Text("agg. \(u.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Toggle("Login", isOn: $launchAtLogin)
                .toggleStyle(.switch).controlSize(.mini)
                .font(.system(size: 10))
                .onChange(of: launchAtLogin) { _, on in
                    try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                }
            Button {
                notifications.toggle()
                SessionWatcher.isEnabled = notifications
            } label: {
                Image(systemName: notifications ? "bell.fill" : "bell.slash").font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(notifications ? AnyShapeStyle(claudeOrange) : AnyShapeStyle(.secondary))
            .help(notifications ? "Avvisi fine sessione: attivi" : "Avvisi fine sessione: disattivati")
            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain).foregroundStyle(.secondary).help("Esci")
        }
    }

    /// Token di oggi e della settimana, dai log locali.
    private var tokenTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 5) {
            GridRow {
                Text("")
                columnTitle("Token")
                columnTitle("Output")
                columnTitle("Risposte")
            }
            tokenRow("Oggi", store.local.today)
            tokenRow("Settimana", store.local.week)
        }
    }

    private func columnTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 9)).foregroundStyle(.secondary)
    }

    private func tokenRow(_ label: String, _ s: TokenStats) -> some View {
        GridRow {
            Text(label).font(.system(size: 11, weight: .medium))
            value(formatTokens(s.tokens))
            value(formatTokens(s.outputTokens))
            value(formatTokens(s.messages))
        }
    }

    private func value(_ v: String) -> some View {
        Text(v).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
    }
}

/// Quota di token per modello nella settimana: barra a segmenti + legenda.
private struct ModelBreakdown: View {
    let models: [ModelUsage]

    private static let palette: [Color] = [
        claudeOrange,
        Color(red: 0.62, green: 0.52, blue: 1.0),
        Color(red: 0.35, green: 0.7, blue: 1.0),
        Color.white.opacity(0.35),
    ]

    /// I primi tre modelli, il resto raggruppato in "Altri".
    private var slices: [ModelUsage] {
        guard models.count > 3 else { return models }
        let rest = models.dropFirst(3)
        return Array(models.prefix(3)) + [ModelUsage(name: "Altri", tokens: rest.reduce(0) { $0 + $1.tokens },
                                                     share: rest.reduce(0) { $0 + $1.share })]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text("Modelli · settimana").font(.system(size: 11, weight: .medium))
                Spacer()
                Text("più usato").font(.system(size: 10)).foregroundStyle(.secondary)
                Text(models[0].name).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(claudeOrange)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(slices.enumerated()), id: \.element.id) { i, m in
                        Capsule().fill(Self.palette[min(i, 3)].gradient)
                            .frame(width: max(3, (geo.size.width - CGFloat(slices.count - 1) * 2) * m.share))
                    }
                }
            }
            .frame(height: 6)
            .animation(.easeOut(duration: 0.6), value: models)
            HStack(spacing: 12) {
                ForEach(Array(slices.enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 4) {
                        Circle().fill(Self.palette[min(i, 3)]).frame(width: 6, height: 6)
                        Text(m.name).font(.system(size: 10))
                        Text("\(Int((m.share * 100).rounded()))%")
                            .font(.system(size: 10, weight: .semibold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct UsageBar: View {
    let title: String
    let window: UsageWindow?
    let now: Date

    var body: some View {
        let pct = window?.percent ?? 0
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 11, weight: .medium))
                Spacer()
                Text(window == nil ? "—" : "\(Int(pct.rounded()))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(color(for: pct))
                Text("reset \(countdown(to: window?.resetsAt, now: now))")
                    .font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.12))
                    Capsule().fill(color(for: pct).gradient)
                        .frame(width: geo.size.width * min(1, pct / 100))
                }
            }
            .frame(height: 6)
            .animation(.easeOut(duration: 0.6), value: pct)
        }
    }
}

private struct Ring: View {
    let percent: Double
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: 2)
            Circle().trim(from: 0, to: min(1, percent / 100))
                .stroke(color(for: percent), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

/// Forma del notch: bordo superiore dritto con piccole curve "inverse" in alto, angoli inferiori arrotondati.
struct NotchShape: Shape {
    var bottomRadius: CGFloat
    var topRadius: CGFloat = 6

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let t = topRadius, b = min(bottomRadius, r.height / 2)
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + t, y: r.minY + t), control: CGPoint(x: r.minX + t, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + t, y: r.maxY - b))
        p.addQuadCurve(to: CGPoint(x: r.minX + t + b, y: r.maxY), control: CGPoint(x: r.minX + t, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - t - b, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - t, y: r.maxY - b), control: CGPoint(x: r.maxX - t, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX - t, y: r.minY + t))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY), control: CGPoint(x: r.maxX - t, y: r.minY))
        p.closeSubpath()
        return p
    }
}
