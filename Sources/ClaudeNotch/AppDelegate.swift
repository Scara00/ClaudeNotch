import AppKit
import SwiftUI

/// Stato condiviso tra finestra e vista: geometria del notch e hover.
@MainActor
final class NotchState: ObservableObject {
    @Published var expanded = false
    @Published var notchWidth: CGFloat = 200
    @Published var notchHeight: CGFloat = 32
    /// Altezza reale del contenuto espanso, misurata dalla vista: il pannello si adatta a quella.
    @Published var contentHeight: CGFloat = 150
    /// Avviso di fine sessione mostrato nel notch (solo da chiuso).
    @Published var alert: SessionAlert?

    /// Larghezza di ciascuna "orecchia": cresce col contenuto scelto, mai sotto il minimo.
    @Published var sideWidth: CGFloat = NotchState.minSideWidth
    static let minSideWidth: CGFloat = 70
    static let expandedWidth: CGFloat = 440
    static let alertSize = CGSize(width: 380, height: 62)

    var collapsedSize: CGSize { CGSize(width: notchWidth + sideWidth * 2, height: notchHeight) }
    var currentSize: CGSize {
        if expanded { return CGSize(width: max(Self.expandedWidth, collapsedSize.width), height: contentHeight + notchHeight) }
        if alert != nil { return CGSize(width: max(Self.alertSize.width, collapsedSize.width), height: Self.alertSize.height + notchHeight) }
        return collapsedSize
    }
}

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel!
    private let store = UsageStore()
    private let sessionWatcher = SessionWatcher()
    private let state = NotchState()
    private var monitors: [Any] = []
    private var collapseWork: DispatchWorkItem?

    private let windowSize = CGSize(width: 560, height: 360)

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = NotchPanel(contentRect: .zero,
                           styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar + 1 // sopra la menu bar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: NotchView(store: store, state: state))

        layout()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.layout() }
        }

        let handler: (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: handler) as Any)
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { e in handler(e); return e } as Any)

        store.start()
        sessionWatcher.onTurnFinished = { [weak self] alert in self?.enqueue(alert) }
        sessionWatcher.start()
    }

    // MARK: - Avvisi di fine sessione

    private var pendingAlerts: [SessionAlert] = []
    private var alertWork: DispatchWorkItem?
    private static let alertDuration: TimeInterval = 6

    private func enqueue(_ alert: SessionAlert) {
        pendingAlerts.append(alert)
        showNextAlertIfIdle()
    }

    private func showNextAlertIfIdle() {
        guard state.alert == nil, !state.expanded, !pendingAlerts.isEmpty else { return }
        let alert = pendingAlerts.removeFirst()
        if UserDefaults.standard.object(forKey: Prefs.alertSound) as? Bool ?? true {
            NSSound(named: "Glass")?.play()
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { state.alert = alert }
        let work = DispatchWorkItem { [weak self] in self?.dismissAlert() }
        alertWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.alertDuration, execute: work)
    }

    private func dismissAlert() {
        alertWork?.cancel(); alertWork = nil
        guard state.alert != nil else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { state.alert = nil }
        // Piccola pausa prima dell'avviso successivo, così si nota il cambio.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.showNextAlertIfIdle() }
    }

    /// Lo schermo col notch (quello integrato), altrimenti lo schermo principale.
    private var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func layout() {
        guard let screen = targetScreen else { return }
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            state.notchWidth = screen.frame.width - left.width - right.width
            state.notchHeight = screen.safeAreaInsets.top
        } else {
            // Nessun notch: simuliamo una "pillola" alta quanto la menu bar.
            state.notchWidth = 160
            state.notchHeight = screen.frame.maxY - screen.visibleFrame.maxY
        }
        let f = screen.frame
        panel.setFrame(NSRect(x: f.midX - windowSize.width / 2, y: f.maxY - windowSize.height,
                              width: windowSize.width, height: windowSize.height), display: true)
    }

    private func updateHover() {
        guard let screen = targetScreen else { return }
        let size = state.currentSize
        let f = screen.frame
        let rect = NSRect(x: f.midX - size.width / 2, y: f.maxY - size.height, width: size.width, height: size.height)
            .insetBy(dx: -4, dy: -4)
        let inside = rect.contains(NSEvent.mouseLocation)

        if inside {
            collapseWork?.cancel(); collapseWork = nil
            if !state.expanded {
                alertWork?.cancel(); alertWork = nil
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    state.alert = nil
                    state.expanded = true
                }
                panel.ignoresMouseEvents = false
                store.refreshLocal() // solo log locali: l'API ha il suo ritmo
            }
        } else if state.expanded, collapseWork == nil {
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { self.state.expanded = false }
                self.panel.ignoresMouseEvents = true
                self.collapseWork = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.showNextAlertIfIdle() }
            }
            collapseWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }
    }
}
