import Foundation

struct AppPreferencesStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedAgent: AgentKind {
        get {
            let raw = defaults.string(forKey: Keys.selectedAgent) ?? ""
            return AgentKind(rawValue: raw) ?? .codex
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.selectedAgent)
        }
    }

    func runtimePath(for agent: AgentKind) -> String {
        if let persisted = defaults.string(forKey: runtimePathKey(for: agent)), !persisted.isEmpty {
            return persisted
        }
        if agent == .codex {
            return defaults.string(forKey: Keys.customCodexPath) ?? ""
        }
        return ""
    }

    func setRuntimePath(_ newValue: String, for agent: AgentKind) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = runtimePathKey(for: agent)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: key)
            if agent == .codex {
                defaults.removeObject(forKey: Keys.customCodexPath)
            }
            return
        }
        defaults.set(trimmed, forKey: key)
        if agent == .codex {
            defaults.set(trimmed, forKey: Keys.customCodexPath)
        }
    }

    var resetDisplayMode: ResetDisplayMode {
        get {
            let raw = defaults.string(forKey: Keys.resetDisplayMode) ?? ""
            return ResetDisplayMode(rawValue: raw) ?? .relative
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.resetDisplayMode)
        }
    }

    var selectedSettingsSection: SettingsSection {
        get {
            let raw = defaults.string(forKey: Keys.selectedSettingsSection) ?? ""
            return SettingsSection(rawValue: raw) ?? .dashboard
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.selectedSettingsSection)
        }
    }

    var selectedSettingsAccountName: String? {
        get {
            defaults.string(forKey: Keys.selectedSettingsAccountName)
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Keys.selectedSettingsAccountName)
            } else {
                defaults.removeObject(forKey: Keys.selectedSettingsAccountName)
            }
        }
    }

    var menuDensity: MenuDensity {
        get {
            let raw = defaults.string(forKey: Keys.menuDensity) ?? ""
            return MenuDensity(rawValue: raw) ?? .compact
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.menuDensity)
        }
    }

    var usageBarStyle: UsageBarStyle {
        get {
            let raw = defaults.string(forKey: Keys.usageBarStyle) ?? ""
            return UsageBarStyle(rawValue: raw) ?? .depleting
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.usageBarStyle)
        }
    }

    var accountSwitchingStrategy: AccountSwitchingStrategy {
        get {
            let raw = defaults.string(forKey: Keys.accountSwitchingStrategy) ?? ""
            return AccountSwitchingStrategy(rawValue: raw) ?? .manual
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.accountSwitchingStrategy)
        }
    }

    var autoSwitchNotificationsEnabled: Bool {
        get { defaults.bool(forKey: Keys.autoSwitchNotificationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.autoSwitchNotificationsEnabled) }
    }

    var limitsCacheTTLSeconds: Int {
        get {
            defaults.integer(forKey: Keys.limitsCacheTTLSeconds)
        }
        set {
            defaults.set(newValue, forKey: Keys.limitsCacheTTLSeconds)
        }
    }

    private func runtimePathKey(for agent: AgentKind) -> String {
        "\(Keys.runtimePathPrefix).\(agent.rawValue)"
    }

    enum Keys {
        static let selectedAgent = "multicodexMenu.selectedAgent"
        static let runtimePathPrefix = "multicodexMenu.runtimePath"
        static let customCodexPath = "multicodexMenu.customCodexPath"
        static let resetDisplayMode = "multicodexMenu.resetDisplayMode"
        static let selectedSettingsSection = "multicodexMenu.selectedSettingsSection"
        static let selectedSettingsAccountName = "multicodexMenu.selectedSettingsAccountName"
        static let menuDensity = "multicodexMenu.menuDensity"
        static let usageBarStyle = "multicodexMenu.usageBarStyle"
        static let accountSwitchingStrategy = "multicodexMenu.accountSwitchingStrategy"
        static let autoSwitchNotificationsEnabled = "multicodexMenu.autoSwitchNotificationsEnabled"
        static let limitsCacheTTLSeconds = "multicodexMenu.limitsCacheTTLSeconds"
    }
}
