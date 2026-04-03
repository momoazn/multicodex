import Foundation

enum AgentKind: String, CaseIterable, Codable, Identifiable {
    case codex
    case pi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex:
            return "Codex"
        case .pi:
            return "Pi"
        }
    }

    var runtimeDisplayName: String {
        switch self {
        case .codex:
            return "codex"
        case .pi:
            return "pi"
        }
    }

    var runtimePathPlaceholder: String {
        switch self {
        case .codex:
            return "/opt/homebrew/bin/codex"
        case .pi:
            return "/opt/homebrew/bin/pi"
        }
    }

    var accountNounSingular: String {
        switch self {
        case .codex:
            return "account"
        case .pi:
            return "profile"
        }
    }

    var accountNounPlural: String {
        switch self {
        case .codex:
            return "accounts"
        case .pi:
            return "profiles"
        }
    }

    var managedStorageName: String {
        rawValue
    }
}
