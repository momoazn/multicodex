import AppKit
import Foundation

@MainActor
final class AccountsMenuViewModel: ObservableObject {
    @Published var accounts: [AccountUsage] = []
    @Published var isRefreshing = false
    @Published var lastRefreshError: String?
    @Published var refreshWarningMessage: String?
    @Published var lastUpdatedAt: Date?
    @Published var switchingAccountName: String?
    @Published var cliResolutionHint: String?
    @Published var accountActionInFlightName: String?
    @Published var accountActionMessage: String?
    @Published var accountActionError: String?
    @Published var runtimeProbeSummary: String?
    @Published var isRuntimeAvailable = false
    @Published var focusedAccountName: String?
    @Published var selectedAgent: AgentKind
    @Published var customRuntimePath: String
    @Published var resetDisplayMode: ResetDisplayMode
    @Published var selectedSettingsSection: SettingsSection
    @Published var selectedSettingsAccountName: String?
    @Published var accountSearchQuery: String
    @Published var isAdvancedSettingsVisible: Bool
    @Published var menuDensity: MenuDensity
    @Published var usageBarStyle: UsageBarStyle
    @Published var accountSwitchingStrategy: AccountSwitchingStrategy
    @Published var autoSwitchNotificationsEnabled: Bool
    @Published var limitsCacheTTLSeconds: Int
    @Published var pendingAccountRemovalRequest: PendingAccountRemovalRequest?

    private let agentRegistry: CodingAgentRegistry
    var accountService: any CodingAgentServicing
    let fileManager: FileManager
    private let autoSwitchNotifierFactory: () -> any AutoSwitchNotificationSending
    var preferences: AppPreferencesStore

    var refreshLoopTask: Task<Void, Never>?
    var didBecomeActiveObserver: NSObjectProtocol?
    var pendingInteractiveLoginSession: PendingInteractiveLoginSession?
    var feedbackAutoClearTask: Task<Void, Never>?
    lazy var autoSwitchNotifier: any AutoSwitchNotificationSending = autoSwitchNotifierFactory()
    lazy var refreshController = AccountsRefreshController(viewModel: self)
    lazy var accountActions = AccountActionController(viewModel: self)
    lazy var settingsController = AccountsSettingsController(viewModel: self)
    lazy var accountManagement = AccountManagementController(viewModel: self)

    convenience init(
        accountService: any CodingAgentServicing,
        fileManager: FileManager = .default,
        autoSwitchNotifier: @escaping () -> any AutoSwitchNotificationSending = { AutoSwitchNotificationCenter.shared },
        preferences: AppPreferencesStore = AppPreferencesStore(),
        startImmediately: Bool = true
    ) {
        let registryServices: [any CodingAgentServicing]
        if accountService.agentKind == .codex {
            registryServices = [accountService, PiAgentService()]
        } else {
            registryServices = [CodexAccountService(), accountService]
        }
        self.init(
            agentRegistry: CodingAgentRegistry(services: registryServices),
            fileManager: fileManager,
            autoSwitchNotifier: autoSwitchNotifier,
            preferences: preferences,
            startImmediately: startImmediately
        )
    }

    convenience init(
        codexService: any CodingAgentServicing = CodexAccountService(),
        piService: any CodingAgentServicing = PiAgentService(),
        fileManager: FileManager = .default,
        autoSwitchNotifier: @escaping () -> any AutoSwitchNotificationSending = { AutoSwitchNotificationCenter.shared },
        preferences: AppPreferencesStore = AppPreferencesStore(),
        startImmediately: Bool = true
    ) {
        self.init(
            agentRegistry: CodingAgentRegistry(services: [codexService, piService]),
            fileManager: fileManager,
            autoSwitchNotifier: autoSwitchNotifier,
            preferences: preferences,
            startImmediately: startImmediately
        )
    }

    init(
        agentRegistry: CodingAgentRegistry,
        fileManager: FileManager = .default,
        autoSwitchNotifier: @escaping () -> any AutoSwitchNotificationSending = { AutoSwitchNotificationCenter.shared },
        preferences: AppPreferencesStore = AppPreferencesStore(),
        startImmediately: Bool = true
    ) {
        self.agentRegistry = agentRegistry
        self.fileManager = fileManager
        autoSwitchNotifierFactory = autoSwitchNotifier
        self.preferences = preferences

        let preferredAgent = preferences.selectedAgent
        let initialAgent = agentRegistry.service(for: preferredAgent)?.agentKind
            ?? agentRegistry.supportedAgents.first
            ?? .codex
        selectedAgent = initialAgent
        guard let service = agentRegistry.service(for: initialAgent) else {
            fatalError("No coding agent service registered for \(initialAgent.rawValue)")
        }
        accountService = service

        customRuntimePath = preferences.runtimePath(for: initialAgent)
        resetDisplayMode = preferences.resetDisplayMode
        selectedSettingsSection = preferences.selectedSettingsSection
        selectedSettingsAccountName = preferences.selectedSettingsAccountName
        accountSearchQuery = ""
        isAdvancedSettingsVisible = false
        menuDensity = preferences.menuDensity
        usageBarStyle = preferences.usageBarStyle
        accountSwitchingStrategy = preferences.accountSwitchingStrategy
        autoSwitchNotificationsEnabled = preferences.autoSwitchNotificationsEnabled
        let persistedTTL = preferences.limitsCacheTTLSeconds
        limitsCacheTTLSeconds = CodexAccountService.normalizedLimitsCacheTTLSeconds(
            persistedTTL > 0 ? persistedTTL : CodexAccountService.defaultLimitsCacheTTLSeconds
        )
        pendingAccountRemovalRequest = nil
        if !isAdvancedSettingsVisible, selectedSettingsSection == .advanced {
            selectedSettingsSection = .dashboard
        }
        applyPreferencesToCurrentService()
        if autoSwitchNotificationsEnabled {
            self.autoSwitchNotifier.requestAuthorizationIfNeeded()
        }
        refreshController.refreshRuntimeProbe()
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshController.handleDidBecomeActive()
            }
        }
        if startImmediately {
            start()
        }
    }

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        refreshLoopTask?.cancel()
    }

    var agentCapabilities: AgentCapabilities { accountService.capabilities }
    var currentAgentTitle: String { selectedAgent.title }
    var currentRuntimeName: String { selectedAgent.runtimeDisplayName }
    var currentAccountNounSingular: String { selectedAgent.accountNounSingular }
    var currentAccountNounPlural: String { selectedAgent.accountNounPlural }
    var supportsUsage: Bool { agentCapabilities.supportsUsage }
    var supportsAutoSwitching: Bool { agentCapabilities.supportsAutoSwitching }

    var currentAccount: AccountUsage? {
        accounts.first(where: { $0.isCurrent })
    }

    var menuBarTitle: String {
        guard let current = currentAccount else {
            return accounts.isEmpty ? "mcx" : "mcx ?"
        }

        if supportsUsage, let percent = current.primaryPercentText {
            return "mcx \(percent)"
        }

        return "mcx \(current.name)"
    }

    var menuBarSymbol: String {
        if lastRefreshError != nil {
            return "exclamationmark.triangle.fill"
        }

        guard supportsUsage else {
            return currentAccount == nil ? "person.2.circle" : "terminal"
        }

        switch UsageLevel.from(usedPercent: currentAccount?.usage.fiveHour.usedPercent) {
        case .critical:
            return "flame.fill"
        case .warning:
            return "gauge.with.dots.needle.67percent"
        case .normal:
            return "person.2.circle"
        }
    }

    var currentFiveHourFraction: Double {
        supportsUsage ? (currentAccount?.usage.fiveHour.normalizedFraction ?? 0) : 0
    }

    var currentWeeklyFraction: Double {
        supportsUsage ? (currentAccount?.usage.weekly.normalizedFraction ?? 0) : 0
    }

    var lastUpdatedLabel: String {
        guard let lastUpdatedAt else {
            return "Not refreshed yet"
        }
        return "Updated \(UsageFormatter.relativeDateFormatter.localizedString(for: lastUpdatedAt, relativeTo: Date()))"
    }

    var accountsNeedingLogin: [AccountUsage] {
        accounts.filter { $0.connectionState == .needsLogin }
    }

    var filteredAccounts: [AccountUsage] {
        let query = accountSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return accounts
        }

        return accounts.filter { account in
            account.name.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedSettingsAccount: AccountUsage? {
        guard let selectedSettingsAccountName else {
            return nil
        }
        return filteredAccounts.first(where: { $0.name == selectedSettingsAccountName })
            ?? accounts.first(where: { $0.name == selectedSettingsAccountName })
    }

    var onboardingState: OnboardingState {
        if !isRuntimeAvailable {
            return OnboardingState(step: .runtime)
        }
        if accounts.isEmpty {
            return OnboardingState(step: .login)
        }
        if accounts.contains(where: { $0.connectionState != .connected }) {
            return OnboardingState(step: .verify)
        }
        return OnboardingState(step: .done)
    }

    var prioritizedMenuAlert: MenuAlertState? {
        MenuAlertPolicy.prioritizedAlert(
            agent: selectedAgent,
            isRuntimeAvailable: isRuntimeAvailable,
            runtimeSummary: runtimeProbeSummary,
            lastRefreshError: lastRefreshError,
            accountsNeedingLogin: accountsNeedingLogin
        )
    }

    var preferredMenuAccountCount: Int {
        switch menuDensity {
        case .compact:
            return 5
        case .comfortable:
            return 4
        }
    }

    var limitsCacheTTLMinutes: Int {
        max(1, Int(round(Double(limitsCacheTTLSeconds) / 60.0)))
    }

    var settingsSections: [SettingsSection] {
        var sections: [SettingsSection] = [
            .dashboard,
            .accounts,
            .runtime,
            .display,
            .troubleshooting,
        ]
        if isAdvancedSettingsVisible {
            sections.append(.advanced)
        }
        return sections
    }

    func menuAccountRows(limit: Int? = nil) -> [AccountRowState] {
        let maxCount = limit ?? preferredMenuAccountCount
        return Array(accounts.prefix(maxCount)).map { account in
            AccountRowState(account: account, resetDisplayMode: resetDisplayMode)
        }
    }

    func start() {
        guard refreshLoopTask == nil else {
            return
        }

        Task { @MainActor in
            await refreshController.performRefresh(refreshLive: false)
            if shouldPreferLiveRefreshForAutoSwitching {
                await refreshController.performRefresh(refreshLive: true)
            }
        }
        startRefreshLoop()
    }

    func startRefreshLoop() {
        refreshLoopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(limitsCacheTTLSeconds))
                if Task.isCancelled {
                    break
                }
                await refreshController.performRefresh(refreshLive: shouldPreferLiveRefreshForAutoSwitching)
            }
        }
    }

    func refresh() {
        refreshController.triggerRefresh(refreshLive: false)
    }

    func refreshLive() {
        refreshController.triggerRefresh(refreshLive: true)
    }

    func performMenuAlertAction(_ action: MenuAlertState.Action) {
        switch action {
        case .openRuntimeSettings:
            selectSettingsSection(.runtime)
        case .refreshLive:
            refreshLive()
        case let .relogin(accountName):
            openLoginInTerminal(for: accountName)
        }
    }

    func selectSettingsSection(_ section: SettingsSection) { settingsController.selectSettingsSection(section) }

    func resetOnboardingWizard() {
        selectSettingsAccount(named: nil)
        selectSettingsSection(.runtime)
    }

    func selectSettingsAccount(named name: String?) { settingsController.selectSettingsAccount(named: name) }
    func setAccountSearchQuery(_ query: String) { settingsController.setAccountSearchQuery(query) }
    func syncSelectedSettingsAccount() { settingsController.syncSelectedSettingsAccount() }
    func setAdvancedSettingsVisible(_ isVisible: Bool) { settingsController.setAdvancedSettingsVisible(isVisible) }
    func setMenuDensity(_ density: MenuDensity) { settingsController.setMenuDensity(density) }
    func setUsageBarStyle(_ style: UsageBarStyle) { settingsController.setUsageBarStyle(style) }
    func setAccountSwitchingStrategy(_ strategy: AccountSwitchingStrategy) { settingsController.setAccountSwitchingStrategy(strategy) }
    func setAutoSwitchNotificationsEnabled(_ isEnabled: Bool) { settingsController.setAutoSwitchNotificationsEnabled(isEnabled) }
    func setLimitsCacheTTLSeconds(_ seconds: Int) { settingsController.setLimitsCacheTTLSeconds(seconds) }
    func setResetDisplayMode(_ mode: ResetDisplayMode) { settingsController.setResetDisplayMode(mode) }
    func updateCustomRuntimePath(_ value: String) { settingsController.updateCustomRuntimePath(value) }
    func clearCustomRuntimePath() { settingsController.clearCustomRuntimePath() }
    func chooseCustomRuntimePath() { settingsController.chooseCustomRuntimePath() }
    func selectAgent(_ agent: AgentKind) { settingsController.selectAgent(agent) }


    var shouldPreferLiveRefreshForAutoSwitching: Bool {
        supportsAutoSwitching && accountSwitchingStrategy != .manual
    }

    func progressValue(for metric: UsageMetric) -> Double {
        guard let usedPercent = metric.usedPercent else {
            return 0
        }
        let usedFraction = min(1, max(0, usedPercent / 100))
        switch usageBarStyle {
        case .depleting:
            return 1 - usedFraction
        case .filling:
            return usedFraction
        }
    }

    func dismissFocusHint() {
        focusedAccountName = nil
    }

    func beginAccountRemoval(named name: String, deleteData: Bool) { accountManagement.beginAccountRemoval(named: name, deleteData: deleteData) }
    func cancelPendingAccountRemoval() { accountManagement.cancelPendingAccountRemoval() }
    func executePendingAccountRemoval(confirming typedName: String?) { accountManagement.executePendingAccountRemoval(confirming: typedName) }
    func switchToAccount(named name: String) { accountManagement.switchToAccount(named: name) }
    func startNewAccountLogin() { accountManagement.startNewAccountLogin() }
    func renameAccount(from oldName: String, to rawNewName: String) { accountManagement.renameAccount(from: oldName, to: rawNewName) }
    func removeAccount(named name: String, deleteData: Bool) { accountManagement.removeAccount(named: name, deleteData: deleteData) }
    func importCurrentAuth(into name: String) { accountManagement.importCurrentAuth(into: name) }
    func checkLoginStatus(for name: String) { accountManagement.checkLoginStatus(for: name) }
    func startLoginFlow(accountName: String, createIfNeeded: Bool) { accountActions.startLoginFlow(accountName: accountName, createIfNeeded: createIfNeeded) }
    func openLoginInTerminal(for name: String) { accountManagement.openLoginInTerminal(for: name) }
    func clearAccountActionFeedback() { accountManagement.clearAccountActionFeedback() }
    func sendTestAutoSwitchNotification() { accountManagement.sendTestAutoSwitchNotification() }
    func openMulticodexConfigDirectory() { accountManagement.openMulticodexConfigDirectory() }

    func runSwitchAction(
        named name: String,
        operation: @escaping () async throws -> Void
    ) {
        guard switchingAccountName == nil else {
            return
        }

        Task {
            switchingAccountName = name
            defer { switchingAccountName = nil }

            do {
                try await operation()
            } catch {
                lastRefreshError = error.localizedDescription
                cliResolutionHint = accountService.resolutionHint
            }
        }
    }

    func applyCurrentAccountLocally(named name: String) {
        accounts = accounts.map { account in
            AccountUsage(
                name: account.name,
                isCurrent: account.name == name,
                hasAuth: account.hasAuth,
                lastUsedAt: account.lastUsedAt,
                lastLoginStatus: account.lastLoginStatus,
                usage: account.usage,
                source: account.source,
                usageError: account.usageError
            )
        }
    }

    func clearFocusedAccountIfMissing() {
        if let focusedAccountName,
           !accounts.contains(where: { $0.name == focusedAccountName })
        {
            self.focusedAccountName = nil
        }
    }

    func switchAgentIfNeeded(_ agent: AgentKind) {
        guard agent != selectedAgent, let newService = agentRegistry.service(for: agent) else {
            return
        }
        selectedAgent = agent
        preferences.selectedAgent = agent
        accountService = newService
        applyPreferencesToCurrentService()
        accounts = []
        lastRefreshError = nil
        refreshWarningMessage = nil
        cliResolutionHint = nil
        runtimeProbeSummary = nil
        focusedAccountName = nil
        selectedSettingsAccountName = nil
        preferences.selectedSettingsAccountName = nil
        pendingInteractiveLoginSession = nil
        refreshController.refreshRuntimeProbe()
        refreshController.triggerRefresh(refreshLive: false)
    }

    private func applyPreferencesToCurrentService() {
        customRuntimePath = preferences.runtimePath(for: selectedAgent)
        accountService.customRuntimePath = customRuntimePath.isEmpty ? nil : customRuntimePath
        accountService.limitsCacheTTLSeconds = limitsCacheTTLSeconds
    }
}
