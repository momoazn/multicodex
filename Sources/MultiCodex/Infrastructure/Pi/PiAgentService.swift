import Foundation

final class PiAgentService: CodingAgentServicing {
    struct PathContext {
        let homeDir: String
        let multicodexHome: String

        var rootDir: String { (multicodexHome as NSString).appendingPathComponent("agents/pi") }
        var configPath: String { (rootDir as NSString).appendingPathComponent("config.json") }
        var accountsDir: String { (rootDir as NSString).appendingPathComponent("accounts") }
        var defaultAgentDir: String { (homeDir as NSString).appendingPathComponent(".pi/agent") }

        func accountDir(_ account: String) -> String {
            (accountsDir as NSString).appendingPathComponent(account)
        }

        func managedAgentDir(_ account: String) -> String {
            (accountDir(account) as NSString).appendingPathComponent("pi-agent")
        }

        func metaPath(_ account: String) -> String {
            (accountDir(account) as NSString).appendingPathComponent("meta.json")
        }

        func authPath(_ account: String) -> String {
            (managedAgentDir(account) as NSString).appendingPathComponent("auth.json")
        }
    }

    struct ProfileMeta: Codable {
        var createdAt: String
        var lastUsedAt: String?
        var lastLoginStatus: String?
        var lastLoginCheckedAt: String?
        var updatedAt: String?
    }

    let agentKind: AgentKind = .pi
    let capabilities: AgentCapabilities = .pi

    let fileManager = FileManager.default
    let decoder = JSONDecoder()
    let encoder = JSONEncoder()
    var processEnvironmentProvider: () -> [String: String] = { ProcessInfo.processInfo.environment }
    var customRuntimePath: String?
    var sandboxHomeDirectory: String?
    var sandboxMulticodexHomeDirectory: String?
    var limitsCacheTTLSeconds: Int = CodexAccountService.defaultLimitsCacheTTLSeconds
    var resolutionHint: String?

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func fetchAccounts() async throws -> AccountsListPayload {
        let paths = currentPaths()
        let config = try loadConfig(paths: paths)
        let current = config.currentAccount
        let accounts = try config.accounts.sorted().map { account -> AccountEntry in
            let authExists = fileManager.fileExists(atPath: paths.authPath(account))
            let meta = try loadMeta(account: account, paths: paths)
            return AccountEntry(
                name: account,
                isCurrent: account == current,
                hasAuth: authExists,
                lastUsedAt: meta?.lastUsedAt,
                lastLoginStatus: meta?.lastLoginStatus
            )
        }
        return AccountsListPayload(accounts: accounts, currentAccount: current)
    }

    func fetchLimits(refreshLive: Bool) async throws -> LimitsPayload {
        _ = refreshLive
        return LimitsPayload(results: [], errors: [])
    }

    func switchAccount(name: String) async throws {
        let account = try validatedAccountName(name)
        let paths = currentPaths()
        var config = try loadConfig(paths: paths)
        guard config.accounts.contains(account) else {
            throw PiAgentServiceError(message: "Unknown profile: \(account)")
        }
        config.currentAccount = account
        try saveConfig(config, paths: paths)
        _ = try updateMeta(account: account, paths: paths) { meta in
            meta.lastUsedAt = Self.nowISO()
        }
    }

    func removeAccount(name: String, deleteData: Bool) async throws -> RemoveAccountPayload {
        let account = try validatedAccountName(name)
        let paths = currentPaths()
        var config = try loadConfig(paths: paths)
        guard config.accounts.contains(account) else {
            throw PiAgentServiceError(message: "Unknown profile: \(account)")
        }
        config.accounts.remove(account)
        if config.currentAccount == account {
            config.currentAccount = config.accounts.sorted().first
        }
        try saveConfig(config, paths: paths)
        if deleteData {
            try? fileManager.removeItem(atPath: paths.accountDir(account))
        }
        return RemoveAccountPayload(removedAccount: account, currentAccount: config.currentAccount)
    }

    func renameAccount(from oldName: String, to newName: String) async throws -> RenameAccountPayload {
        let source = try validatedAccountName(oldName)
        let target = try validatedAccountName(newName)
        let paths = currentPaths()
        var config = try loadConfig(paths: paths)
        guard config.accounts.contains(source) else {
            throw PiAgentServiceError(message: "Unknown profile: \(source)")
        }
        guard !config.accounts.contains(target) else {
            throw PiAgentServiceError(message: "Profile already exists: \(target)")
        }
        try ensureRootDirectories(paths: paths)
        try fileManager.moveItem(atPath: paths.accountDir(source), toPath: paths.accountDir(target))
        config.accounts.remove(source)
        config.accounts.insert(target)
        if config.currentAccount == source {
            config.currentAccount = target
        }
        try saveConfig(config, paths: paths)
        _ = try updateMeta(account: target, paths: paths) { meta in
            meta.updatedAt = Self.nowISO()
        }
        return RenameAccountPayload(from: source, to: target, currentAccount: config.currentAccount)
    }

    func importDefaultAuth(into name: String) async throws -> ImportAccountPayload {
        try await importAuth(fromHome: currentPaths().homeDir, into: name)
    }

    func importAuth(fromHome homePath: String, into name: String) async throws -> ImportAccountPayload {
        let account = try addAccountIfNeeded(name: name)
        let sourceAgentDir = Self.agentDirectory(forHome: homePath)
        let sourceAuthPath = (sourceAgentDir as NSString).appendingPathComponent("auth.json")
        guard fileManager.fileExists(atPath: sourceAuthPath) else {
            throw PiAgentServiceError(message: "Login did not produce a usable pi auth session.")
        }
        let paths = currentPaths()
        let targetAgentDir = paths.managedAgentDir(account)
        try ensureDirectory(targetAgentDir)
        try copyItemReplacing(sourceAuthPath, to: paths.authPath(account))
        for optionalName in ["settings.json", "models.json"] {
            let source = (sourceAgentDir as NSString).appendingPathComponent(optionalName)
            let target = (targetAgentDir as NSString).appendingPathComponent(optionalName)
            if fileManager.fileExists(atPath: source) {
                try copyItemReplacing(source, to: target)
            }
        }
        let sourceSessions = (sourceAgentDir as NSString).appendingPathComponent("sessions")
        let targetSessions = (targetAgentDir as NSString).appendingPathComponent("sessions")
        if fileManager.fileExists(atPath: sourceSessions) {
            try replaceDirectory(sourceSessions, targetSessions)
        }
        _ = try updateMeta(account: account, paths: paths) { meta in
            meta.lastUsedAt = Self.nowISO()
            meta.lastLoginCheckedAt = Self.nowISO()
            meta.lastLoginStatus = "Login detected in managed pi profile."
        }
        return ImportAccountPayload(account: account)
    }

    func fetchStatus(name: String) async throws -> AccountStatusPayload {
        let account = try validatedAccountName(name)
        let paths = currentPaths()
        let authPath = paths.authPath(account)
        let hasAuth = fileManager.fileExists(atPath: authPath)
        let output = hasAuth ? "Pi auth is available." : "Pi auth is missing. Launch pi and run /login."
        _ = try updateMeta(account: account, paths: paths) { meta in
            meta.lastLoginCheckedAt = Self.nowISO()
            meta.lastLoginStatus = output
        }
        return AccountStatusPayload(
            account: account,
            exitCode: hasAuth ? 0 : 1,
            stdout: output,
            stderr: "",
            output: output,
            checkedAt: Self.nowISO()
        )
    }

    func fetchStatusForLoginHome(_ homePath: String, accountName: String) async throws -> AccountStatusPayload {
        let authPath = (Self.agentDirectory(forHome: homePath) as NSString).appendingPathComponent("auth.json")
        let hasAuth = fileManager.fileExists(atPath: authPath)
        let output = hasAuth ? "Pi login captured." : "Pi login not detected yet. Complete /login and try again."
        return AccountStatusPayload(
            account: accountName,
            exitCode: hasAuth ? 0 : 1,
            stdout: output,
            stderr: "",
            output: output,
            checkedAt: Self.nowISO()
        )
    }

    func openLoginInTerminal(account name: String, loginHome: String?) throws {
        let account = try validatedAccountName(name)
        let loginRoot = loginHome ?? currentPaths().homeDir
        let script = try makeTerminalPiLoginCommand(accountName: account, firstTime: false, loginHome: loginRoot)
        try launchTerminal(script: script)
    }

    func openNewAccountLoginInTerminal(newAccountName name: String, loginHome: String?) throws {
        let account = try addAccountIfNeeded(name: name)
        let loginRoot = loginHome ?? currentPaths().homeDir
        let script = try makeTerminalPiLoginCommand(accountName: account, firstTime: true, loginHome: loginRoot)
        try launchTerminal(script: script)
    }

    func loginInApp(account name: String, createIfNeeded: Bool, loginHome: String?) async throws -> String {
        _ = name
        _ = createIfNeeded
        _ = loginHome
        throw PiAgentServiceError(message: "Pi login requires an interactive terminal session.")
    }

    func effectiveMulticodexHomePath() -> String {
        currentPaths().rootDir
    }

    func probeRuntime() -> RuntimeProbe {
        do {
            let environment = baseEnvironment()
            let runtime = try resolveRuntime(environment: environment)
            let output = ProcessOutputReader.run(
                executableURL: runtime.executableURL,
                arguments: runtime.prefixArguments + ["--version"],
                environment: environment
            )
            updateResolutionHint(runtime: runtime)
            if let output {
                let summary = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return RuntimeProbe(isAvailable: true, summary: summary.isEmpty ? "pi runtime is available." : summary)
            }
            return RuntimeProbe(isAvailable: false, summary: "pi runtime check failed.")
        } catch {
            return RuntimeProbe(isAvailable: false, summary: error.localizedDescription)
        }
    }

    private func currentPaths(loginHome: String? = nil) -> PathContext {
        let home = firstNonEmptyPath(
            fallback: NSHomeDirectory(),
            loginHome,
            sandboxHomeDirectory
        )
        let multicodexHome = firstNonEmptyPath(
            fallback: (home as NSString).appendingPathComponent(".config/multicodex"),
            sandboxMulticodexHomeDirectory,
            processEnvironmentProvider()["MULTICODEX_HOME"]
        )
        return PathContext(homeDir: home, multicodexHome: multicodexHome)
    }

    private func firstNonEmptyPath(fallback: String, _ candidates: String?...) -> String {
        for candidate in candidates {
            if let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return (candidate as NSString).expandingTildeInPath
            }
        }
        return (fallback as NSString).expandingTildeInPath
    }

    private func loadConfig(paths: PathContext) throws -> AccountConfigRecord {
        let data = fileManager.contents(atPath: paths.configPath)
        return try AccountConfigStore.decodeConfig(from: data)
    }

    private func saveConfig(_ config: AccountConfigRecord, paths: PathContext) throws {
        try ensureRootDirectories(paths: paths)
        let data = try AccountConfigStore.encodeConfig(config)
        try writeFileAtomic(data: data + Data("\n".utf8), path: paths.configPath)
    }

    private func ensureRootDirectories(paths: PathContext) throws {
        try ensureDirectory(paths.rootDir)
        try ensureDirectory(paths.accountsDir)
    }

    private func addAccountIfNeeded(name: String) throws -> String {
        let account = try validatedAccountName(name)
        let paths = currentPaths()
        var config = try loadConfig(paths: paths)
        if !config.accounts.contains(account) {
            config.accounts.insert(account)
            if config.currentAccount == nil {
                config.currentAccount = account
            }
            try saveConfig(config, paths: paths)
            let agentDir = paths.managedAgentDir(account)
            try ensureDirectory(agentDir)
            _ = try updateMeta(account: account, paths: paths) { _ in }
        }
        return account
    }

    private func loadMeta(account: String, paths: PathContext) throws -> ProfileMeta? {
        guard let data = fileManager.contents(atPath: paths.metaPath(account)) else {
            return nil
        }
        return try decoder.decode(ProfileMeta.self, from: data)
    }

    private func updateMeta(account: String, paths: PathContext, transform: (inout ProfileMeta) -> Void) throws -> ProfileMeta {
        let existing = try loadMeta(account: account, paths: paths)
        var meta = existing ?? ProfileMeta(createdAt: Self.nowISO(), lastUsedAt: nil, lastLoginStatus: nil, lastLoginCheckedAt: nil, updatedAt: nil)
        transform(&meta)
        meta.updatedAt = Self.nowISO()
        let data = try encoder.encode(meta)
        try ensureDirectory(paths.accountDir(account))
        try writeFileAtomic(data: data + Data("\n".utf8), path: paths.metaPath(account))
        return meta
    }

    private func validatedAccountName(_ name: String) throws -> String {
        let account = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty, account.range(of: "^[a-zA-Z0-9_-]+$", options: .regularExpression) != nil else {
            throw PiAgentServiceError(message: "Invalid profile name. Use letters, numbers, underscore, or dash.")
        }
        return account
    }

    private func ensureDirectory(_ path: String) throws {
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    private func copyItemReplacing(_ source: String, to destination: String) throws {
        let parent = (destination as NSString).deletingLastPathComponent
        try ensureDirectory(parent)
        if fileManager.fileExists(atPath: destination) {
            try fileManager.removeItem(atPath: destination)
        }
        try fileManager.copyItem(atPath: source, toPath: destination)
    }

    private func replaceDirectory(_ source: String, _ destination: String) throws {
        let parent = (destination as NSString).deletingLastPathComponent
        try ensureDirectory(parent)
        if fileManager.fileExists(atPath: destination) {
            try fileManager.removeItem(atPath: destination)
        }
        try fileManager.copyItem(atPath: source, toPath: destination)
    }

    private func writeFileAtomic(data: Data, path: String) throws {
        let parent = (path as NSString).deletingLastPathComponent
        try ensureDirectory(parent)
        let url = URL(fileURLWithPath: path)
        try data.write(to: url, options: .atomic)
    }

    private func baseEnvironment(loginHome: String? = nil) -> [String: String] {
        var env = processEnvironmentProvider()
        env["PATH"] = ExecutableSearchPath.merge([env["PATH"], ExecutableSearchPath.fallback])
        env["PI_CODING_AGENT_DIR"] = Self.agentDirectory(forHome: loginHome ?? currentPaths().homeDir)
        return env
    }

    private func resolveRuntime(environment: [String: String]) throws -> PiRuntimeDescriptor {
        let runtime = try PiRuntimeResolver.resolve(
            customRuntimePath: customRuntimePath,
            fileManager: fileManager,
            environment: environment
        )
        updateResolutionHint(runtime: runtime)
        return runtime
    }

    private func updateResolutionHint(runtime: PiRuntimeDescriptor) {
        let paths = currentPaths()
        resolutionHint = "Pi runtime: \(runtime.display) | HOME: \(paths.homeDir) | PI_CODING_AGENT_DIR: \(paths.defaultAgentDir) | MULTICODEX_HOME: \(paths.rootDir)"
    }

    private func launchTerminal(script: String) throws {
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e", "tell application \"Terminal\"",
            "-e", "if not (exists front window) then",
            "-e", "do script \"\(escaped)\"",
            "-e", "else",
            "-e", "do script \"\(escaped)\" in front window",
            "-e", "end if",
            "-e", "activate",
            "-e", "end tell",
        ]

        do {
            try process.run()
        } catch {
            throw PiAgentServiceError(message: "Could not open Terminal for login: \(error.localizedDescription)")
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw PiAgentServiceError(message: "Could not launch Terminal login session (exit \(process.terminationStatus)).")
        }
    }

    private func makeTerminalPiLoginCommand(accountName: String, firstTime: Bool, loginHome: String) throws -> String {
        let appName = shellQuote("MultiCodex")
        let account = shellQuote(accountName)
        let environment = baseEnvironment(loginHome: loginHome)
        let runtime = try resolveRuntime(environment: environment)
        let command = ([runtime.executableURL.path] + runtime.prefixArguments).map(shellQuote).joined(separator: " ")
        let agentDir = shellQuote(Self.agentDirectory(forHome: loginHome))
        let pathValue = shellQuote(environment["PATH"] ?? ExecutableSearchPath.fallback)

        var lines = [
            "export PATH=\(pathValue)",
            "export PI_CODING_AGENT_DIR=\(agentDir)",
        ]
        if firstTime {
            lines.append("echo \"Starting first-time MultiCodex pi login for \(account)...\"")
        } else {
            lines.append("echo \"Starting MultiCodex pi login for \(account)...\"")
        }
        lines.append("echo \"When pi opens, run /login and finish authentication.\"")
        lines.append(command)
        lines.append("LOGIN_EXIT=$?")
        lines.append("if [ \"$LOGIN_EXIT\" -eq 0 ]; then")
        lines.append("  echo \"pi session exited. Return to MultiCodex to import the login.\"")
        lines.append("else")
        lines.append("  echo \"pi exited with status $LOGIN_EXIT.\"")
        lines.append("fi")
        lines.append("open -a \(appName) >/dev/null 2>&1 || true")
        lines.append("exit $LOGIN_EXIT")
        return lines.joined(separator: "\n")
    }

    private func shellQuote(_ value: String) -> String {
        if value.isEmpty {
            return "''"
        }
        let escaped = value.replacingOccurrences(of: "'", with: "'\"'\"'")
        return "'\(escaped)'"
    }

    private static func agentDirectory(forHome homePath: String) -> String {
        (homePath as NSString).appendingPathComponent(".pi/agent")
    }

    private static let nowFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func nowISO() -> String {
        nowFormatter.string(from: Date())
    }
}

struct PiAgentServiceError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
