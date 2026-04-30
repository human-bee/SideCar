import AppKit
import CodexAdapter
import SwiftUI
import UIComponents

@MainActor
@main
enum SideCarLauncher {
    private static var delegate: SideCarAppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = SideCarAppDelegate()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class SideCarAppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settingsPanel: NSPanel?
    private var localHotKeyMonitor: Any?
    private var globalHotKeyMonitor: Any?
    private let viewModel = SideCarViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureLiveReload()
        configureStatusItem()
        configureHotKeyScaffold()
        showPanel()
        probeCodex()
    }

    private func configureLiveReload() {
        viewModel.liveReload = {
            await Task.detached(priority: .utility) {
                let client = CodexAppServerClient()
                let snapshots = client.loadBestAvailableSnapshots(includeActiveTurns: false)
                let probe = client.probe()
                return (snapshots, probe)
            }.value
        }
        viewModel.liveActionExecutor = { action in
            try await Task.detached(priority: .userInitiated) {
                let result = try CodexAppServerClient().executeLiveAction(action)
                return result.map { String(describing: $0) }
            }.value
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.connected.to.line.below", accessibilityDescription: "SideCar")
        item.button?.action = #selector(togglePanel)
        item.button?.target = self

        let menu = NSMenu()
        let showItem = NSMenuItem(title: "Show SideCar", action: #selector(showPanelAction), keyEquivalent: " ")
        showItem.keyEquivalentModifierMask = [.option]
        menu.addItem(showItem)
        let talkItem = NSMenuItem(title: "Start Realtime Voice", action: #selector(startRealtimeVoiceAction), keyEquivalent: " ")
        talkItem.keyEquivalentModifierMask = [.option, .shift]
        menu.addItem(talkItem)
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(showSettingsAction), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func configureHotKeyScaffold() {
        localHotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleLocalHotKey(event) ?? event
        }
        globalHotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalHotKey(event)
        }
    }

    private func handleLocalHotKey(_ event: NSEvent) -> NSEvent? {
        switch hotKeyIntent(for: event) {
        case .togglePanel:
            togglePanel()
            return nil
        case .startRealtimeVoice:
            startRealtimeVoice()
            return nil
        case .none:
            return event
        }
    }

    private func handleGlobalHotKey(_ event: NSEvent) {
        switch hotKeyIntent(for: event) {
        case .togglePanel:
            togglePanel()
        case .startRealtimeVoice:
            startRealtimeVoice()
        case .none:
            break
        }
    }

    private func hotKeyIntent(for event: NSEvent) -> HotKeyIntent? {
        guard event.charactersIgnoringModifiers == " " else { return nil }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == [.option, .shift] {
            return .startRealtimeVoice
        }
        if flags == .option {
            return .togglePanel
        }
        return nil
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 760),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "SideCar"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titlebarAppearsTransparent = true
        panel.contentView = NSHostingView(rootView: SideCarRootView(viewModel: viewModel))
        panel.minSize = NSSize(width: 430, height: 640)
        return panel
    }

    private func makeSettingsPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "SideCar Settings"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.contentView = NSHostingView(rootView: SideCarSettingsView(viewModel: viewModel))
        return panel
    }

    @objc private func togglePanel() {
        guard let panel else {
            showPanel()
            return
        }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    @objc private func showPanelAction() {
        showPanel()
    }

    @objc private func showSettingsAction() {
        showSettings()
    }

    @objc private func startRealtimeVoiceAction() {
        startRealtimeVoice()
    }

    private func startRealtimeVoice() {
        showPanel()
        Task {
            await viewModel.startRealtimeVoiceSession()
        }
    }

    private func showPanel() {
        if panel == nil {
            panel = makePanel()
        }
        guard let panel else { return }
        if let screenFrame = NSScreen.main?.visibleFrame {
            let size = panel.frame.size
            let origin = NSPoint(
                x: screenFrame.maxX - size.width - 28,
                y: screenFrame.maxY - size.height - 28
            )
            panel.setFrameOrigin(origin)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showSettings() {
        if settingsPanel == nil {
            settingsPanel = makeSettingsPanel()
        }
        guard let settingsPanel else { return }
        settingsPanel.center()
        settingsPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func probeCodex() {
        viewModel.reloadFromBestAvailableSource()
    }

    @objc private func quit() {
        if let localHotKeyMonitor {
            NSEvent.removeMonitor(localHotKeyMonitor)
        }
        if let globalHotKeyMonitor {
            NSEvent.removeMonitor(globalHotKeyMonitor)
        }
        NSApp.terminate(nil)
    }
}

private enum HotKeyIntent {
    case togglePanel
    case startRealtimeVoice
}
