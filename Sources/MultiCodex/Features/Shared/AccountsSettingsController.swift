import AppKit
import Foundation

@MainActor
final class AccountsSettingsController {
    unowned let viewModel: AccountsMenuViewModel

    init(viewModel: AccountsMenuViewModel) {
        self.viewModel = viewModel
    }

    func selectSettingsSection(_ section: SettingsSection) {
        if section == .advanced, !viewModel.isAdvancedSettingsVisible {
            setAdvancedSettingsVisible(true)
        }
        viewModel.selectedSettingsSection = section
        viewModel.preferences.selectedSettingsSection = section
    }

    func selectSettingsAccount(named name: String?) {
        viewModel.selectedSettingsAccountName = name
        viewModel.preferences.selectedSettingsAccountName = name
    }

    func setAccountSearchQuery(_ query: String) {
        viewModel.accountSearchQuery = query
        syncSelectedSettingsAccount()
    }

    func syncSelectedSettingsAccount() {
        let candidates = viewModel.filteredAccounts
        guard !candidates.isEmpty else {
            viewModel.selectedSettingsAccountName = nil
            viewModel.preferences.selectedSettingsAccountName = nil
            return
        }

        if let selectedSettingsAccountName = viewModel.selectedSettingsAccountName,
           candidates.contains(where: { $0.name == selectedSettingsAccountName }) {
            return
        }

        if let currentAccount = viewModel.currentAccount,
           candidates.contains(where: { $0.name == currentAccount.name }) {
            selectSettingsAccount(named: currentAccount.name)
            return
        }

        selectSettingsAccount(named: candidates.first?.name)
    }

    func setAdvancedSettingsVisible(_ isVisible: Bool) {
        viewModel.isAdvancedSettingsVisible = isVisible
        if !isVisible, viewModel.selectedSettingsSection == .advanced {
            selectSettingsSection(.dashboard)
        }
    }

    func setMenuDensity(_ density: MenuDensity) {
        guard density != viewModel.menuDensity else {
            return
        }
        viewModel.menuDensity = density
        viewModel.preferences.menuDensity = density
    }

    func setUsageBarStyle(_ style: UsageBarStyle) {
        guard style != viewModel.usageBarStyle else {
            return
        }
        viewModel.usageBarStyle = style
        viewModel.preferences.usageBarStyle = style
    }

    func setAccountSwitchingStrategy(_ strategy: AccountSwitchingStrategy) {
        guard strategy != viewModel.accountSwitchingStrategy else {
            return
        }
        viewModel.accountSwitchingStrategy = strategy
        viewModel.preferences.accountSwitchingStrategy = strategy
        if strategy != .manual, viewModel.supportsAutoSwitching {
            viewModel.refreshLive()
        }
    }

    func setAutoSwitchNotificationsEnabled(_ isEnabled: Bool) {
        guard isEnabled != viewModel.autoSwitchNotificationsEnabled else {
            return
        }
        viewModel.autoSwitchNotificationsEnabled = isEnabled
        viewModel.preferences.autoSwitchNotificationsEnabled = isEnabled
        if isEnabled {
            viewModel.autoSwitchNotifier.requestAuthorizationIfNeeded()
        }
    }

    func setLimitsCacheTTLSeconds(_ seconds: Int) {
        let normalized = CodexAccountService.normalizedLimitsCacheTTLSeconds(seconds)
        guard normalized != viewModel.limitsCacheTTLSeconds else {
            return
        }
        viewModel.limitsCacheTTLSeconds = normalized
        viewModel.preferences.limitsCacheTTLSeconds = normalized
        viewModel.accountService.limitsCacheTTLSeconds = normalized
        viewModel.refreshLoopTask?.cancel()
        viewModel.refreshLoopTask = nil
        viewModel.startRefreshLoop()
    }

    func setResetDisplayMode(_ mode: ResetDisplayMode) {
        guard mode != viewModel.resetDisplayMode else {
            return
        }
        viewModel.resetDisplayMode = mode
        viewModel.preferences.resetDisplayMode = mode
    }

    func updateCustomRuntimePath(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        viewModel.customRuntimePath = trimmed
        viewModel.preferences.setRuntimePath(trimmed, for: viewModel.selectedAgent)
        viewModel.accountService.customRuntimePath = trimmed.isEmpty ? nil : trimmed
        viewModel.refreshController.refreshRuntimeProbe()
        viewModel.refresh()
    }

    func clearCustomRuntimePath() {
        updateCustomRuntimePath("")
    }

    func chooseCustomRuntimePath() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Use"
        panel.message = "Choose the \(viewModel.currentRuntimeName) executable"

        if panel.runModal() == .OK, let path = panel.url?.path {
            updateCustomRuntimePath(path)
        }
    }

    func selectAgent(_ agent: AgentKind) {
        viewModel.switchAgentIfNeeded(agent)
    }
}
