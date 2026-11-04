import AppKit
import SwiftUI

/// With `MULTICODEX_DEMO=1 MULTICODEX_DEMO_CAPTURE=<dir>`, the app shows its main views
/// in normal windows, saves a PNG of each with `screencapture`, and quits.
/// Used for README screenshots and UI review. `MULTICODEX_DEMO_APPEARANCE=light|dark`
/// forces the appearance.
@MainActor
enum DemoCapture {
    static weak var viewModel: AccountsMenuViewModel?
    private static var windows: [NSWindow] = []

    static func startIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard DemoMode.isEnabled else { return }
        switch env["MULTICODEX_DEMO_APPEARANCE"] {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        guard let outputDir = env["MULTICODEX_DEMO_CAPTURE"] else { return }
        Task { await capture(to: URL(fileURLWithPath: outputDir, isDirectory: true)) }
    }

    private static func capture(to outputDir: URL) async {
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        // The view model is created when the menu bar scene first renders.
        while viewModel == nil { try? await Task.sleep(nanoseconds: 100_000_000) }
        guard let viewModel else { return }
        while viewModel.accounts.isEmpty || viewModel.isRefreshing {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        let menu = show(AccountsMenuContentView(viewModel: viewModel).frame(width: 480), title: "Menu", size: nil)
        try? await Task.sleep(nanoseconds: 800_000_000)
        snapshot(menu, to: outputDir.appendingPathComponent("menu.png"))
        menu.close()

        let settings = show(SettingsContentView(viewModel: viewModel), title: "Settings", size: NSSize(width: 820, height: 600))
        for section in SettingsSection.allCases {
            viewModel.selectedSettingsSection = section
            try? await Task.sleep(nanoseconds: 700_000_000)
            snapshot(settings, to: outputDir.appendingPathComponent("settings-\(section.rawValue).png"))
        }
        NSApp.terminate(nil)
    }

    private static func show(_ view: some View, title: String, size: NSSize?) -> NSWindow {
        let hosting = NSHostingView(rootView: view)
        let contentSize = size ?? hosting.fittingSize
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        windows.append(window)
        return window
    }

    private static func snapshot(_ window: NSWindow, to url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", "\(window.windowNumber)", url.path]
        try? process.run()
        process.waitUntilExit()
    }
}
