import Foundation

/// Demo mode: `MULTICODEX_DEMO=1` runs the app on fake in-memory accounts.
/// It never reads or writes ~/.codex or the real MultiCodex config, so it is safe
/// for screenshots and UI work. Preferences go to a separate defaults suite.
enum DemoMode {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["MULTICODEX_DEMO"] == "1"
    }

    static func makePreferences() -> AppPreferencesStore {
        let suite = "multicodex.demo"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return AppPreferencesStore(defaults: defaults)
    }
}

final class DemoAccountService: CodexAccountServicing {
    private struct DemoAccount {
        var name: String
        var email: String?
        var plan: String
        var fiveHour: Double?
        var weekly: Double?
        var fiveHourResetMins: Double
        var weeklyResetMins: Double
    }

    var customCodexPath: String?
    var limitsCacheTTLSeconds: Int = CodexAccountService.defaultLimitsCacheTTLSeconds
    var resolutionHint: String? { nil }

    private var current = "work"
    private var accounts: [DemoAccount] = [
        DemoAccount(name: "work", email: "dev@example.com", plan: "pro", fiveHour: 42, weekly: 18, fiveHourResetMins: 134, weeklyResetMins: 4_100),
        DemoAccount(name: "personal", email: "me@example.com", plan: "plus", fiveHour: 86, weekly: 61, fiveHourResetMins: 47, weeklyResetMins: 2_300),
        DemoAccount(name: "research", email: "lab@example.com", plan: "plus", fiveHour: 100, weekly: 74, fiveHourResetMins: 95, weeklyResetMins: 6_900),
        DemoAccount(name: "side-project", email: "side@example.com", plan: "team", fiveHour: 7, weekly: 3, fiveHourResetMins: 280, weeklyResetMins: 9_200),
        DemoAccount(name: "old-team", email: nil, plan: "plus", fiveHour: nil, weekly: nil, fiveHourResetMins: 0, weeklyResetMins: 0),
    ]
    private let root = (NSTemporaryDirectory() as NSString).appendingPathComponent("multicodex-demo")

    func fetchAccounts() async throws -> AccountsListPayload {
        AccountsListPayload(
            accounts: accounts.map {
                AccountEntry(
                    name: $0.name,
                    isCurrent: $0.name == current,
                    hasAuth: $0.email != nil,
                    lastUsedAt: nil,
                    lastLoginStatus: nil,
                    defaultWorkspaceEmail: $0.email
                )
            },
            currentAccount: current
        )
    }

    func fetchLimits(refreshLive: Bool) async throws -> LimitsPayload {
        limits()
    }

    func fetchLimits(
        refreshLive: Bool,
        cancellationToken: RefreshCancellationToken,
        onPartialResult: @escaping @Sendable (LimitsPayload) -> Void
    ) async throws -> LimitsPayload {
        try await Task.sleep(nanoseconds: 300_000_000)
        return limits()
    }

    func fetchCachedLimits() async throws -> LimitsPayload {
        limits()
    }

    private func limits() -> LimitsPayload {
        let now = Date().timeIntervalSince1970
        var results: [LimitsResult] = []
        var errors: [LimitsErrorEntry] = []
        for account in accounts {
            guard let fiveHour = account.fiveHour, let weekly = account.weekly else {
                errors.append(LimitsErrorEntry(account: account.name, message: "Not logged in. Run `codex` to authenticate."))
                continue
            }
            results.append(LimitsResult(
                account: account.name,
                source: "live-api",
                snapshot: RateLimitSnapshot(
                    primary: RateLimitWindow(usedPercent: fiveHour, windowDurationMins: 300, resetsAt: now + account.fiveHourResetMins * 60),
                    secondary: RateLimitWindow(usedPercent: weekly, windowDurationMins: 10_080, resetsAt: now + account.weeklyResetMins * 60),
                    credits: nil
                ),
                ageSec: 0
            ))
        }
        return LimitsPayload(results: results, errors: errors)
    }

    func switchAccount(name: String) async throws { current = name }
    func forceSwitchAccount(name: String) async throws { current = name }

    func addAccount(name: String) async throws -> AddAccountPayload {
        accounts.append(DemoAccount(name: name, email: nil, plan: "plus", fiveHour: nil, weekly: nil, fiveHourResetMins: 0, weeklyResetMins: 0))
        return AddAccountPayload(account: name, currentAccount: current)
    }

    func removeAccount(name: String, deleteData: Bool) async throws -> RemoveAccountPayload {
        accounts.removeAll { $0.name == name }
        if current == name { current = accounts.first?.name ?? "" }
        return RemoveAccountPayload(removedAccount: name, currentAccount: current)
    }

    func renameAccount(from oldName: String, to newName: String) async throws -> RenameAccountPayload {
        if let index = accounts.firstIndex(where: { $0.name == oldName }) { accounts[index].name = newName }
        if current == oldName { current = newName }
        return RenameAccountPayload(from: oldName, to: newName, currentAccount: current)
    }

    func importDefaultAuth(into name: String) async throws -> ImportAccountPayload { ImportAccountPayload(account: name) }
    func importAuth(fromHome homePath: String, into name: String) async throws -> ImportAccountPayload { ImportAccountPayload(account: name) }

    func fetchStatus(name: String) async throws -> AccountStatusPayload {
        AccountStatusPayload(account: name, exitCode: 0, stdout: "Logged in", stderr: "", output: "Logged in", checkedAt: ISO8601DateFormatter().string(from: Date()))
    }

    func fetchStatusForLoginHome(_ homePath: String, accountName: String) async throws -> AccountStatusPayload {
        try await fetchStatus(name: accountName)
    }

    func openLoginInTerminal(account name: String, loginHome: String?) throws {}
    func openNewAccountLoginInTerminal(newAccountName name: String, loginHome: String?) throws {}
    func loginInApp(account name: String, createIfNeeded: Bool, loginHome: String?) async throws -> String { "Demo mode: login skipped." }
    func inferDefaultWorkspaceEmail(fromLoginHome homePath: String) -> String? { nil }
    func effectiveMulticodexHomePath() -> String { root }
    func probeRuntime() -> RuntimeProbe { RuntimeProbe(isAvailable: true, summary: "codex 0.50.0 (demo)") }
    func refreshStaleTokens() async -> [String: Error] { [:] }
    func persistCurrentAccountIfKnown(_ name: String) throws {}
    func storedAuthModifiedDate(for account: String, paths: CodexAccountService.PathContext) -> Date? { nil }
    func resolveFromAuthPayload(_ authPayload: [String: Any]) -> ResolvedAccountIdentity? { nil }

    func resolvedIdentityForAccount(name: String) -> ResolvedAccountIdentity? {
        guard let account = accounts.first(where: { $0.name == name }), account.email != nil else { return nil }
        return ResolvedAccountIdentity(email: account.email, plan: account.plan, accountId: nil, authMethod: .oauth)
    }

    func currentPaths(loginHome: String?) -> CodexAccountService.PathContext {
        CodexAccountService.PathContext(homeDir: root, multicodexHome: (root as NSString).appendingPathComponent("config"))
    }
}
