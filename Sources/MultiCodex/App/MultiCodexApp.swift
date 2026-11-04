import SwiftUI

@main
struct MultiCodexApp: App {
    @NSApplicationDelegateAdaptor(MultiCodexAppDelegate.self) private var appDelegate
    @StateObject private var viewModel = MultiCodexApp.makeViewModel()

    init() {
        // A codex child process can exit before we write its stdin. Report that as a
        // write error instead of letting SIGPIPE kill the app.
        signal(SIGPIPE, SIG_IGN)
    }

    @MainActor
    private static func makeViewModel() -> AccountsMenuViewModel {
        guard DemoMode.isEnabled else { return AccountsMenuViewModel() }
        let viewModel = AccountsMenuViewModel(
            accountService: DemoAccountService(),
            preferences: DemoMode.makePreferences()
        )
        DemoCapture.viewModel = viewModel
        return viewModel
    }

    var body: some Scene {
        MenuBarExtra {
            AccountsMenuContentView(viewModel: viewModel)
                .frame(
                    minWidth: 460,
                    idealWidth: 480
                )
        } label: {
            let current = viewModel.accounts.first(where: { $0.isCurrent })
            let isStale = current?.connectionState != .connected

            Image(nsImage: MenuBarIconRenderer.render(
                fiveHourProgress: current.map { viewModel.progressValue(for: $0.usage.fiveHour) } ?? 0,
                weeklyProgress: current.map { viewModel.progressValue(for: $0.usage.weekly) } ?? 0,
                fiveHourUsedPercent: current?.usage.fiveHour.usedPercent,
                weeklyUsedPercent: current?.usage.weekly.usedPercent,
                isStale: isStale
            ))
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Settings", id: "settings") {
            SettingsContentView(viewModel: viewModel)
                .frame(
                    minWidth: 560,
                    idealWidth: 600,
                    minHeight: 400,
                    idealHeight: 440
                )
        }

        WindowGroup("Batch Login Tracker", id: "batch-login") {
            SequentialLoginTrackerView(viewModel: viewModel)
                .frame(
                    minWidth: 520,
                    idealWidth: 580,
                    minHeight: 400,
                    idealHeight: 480
                )
        }
    }
}
