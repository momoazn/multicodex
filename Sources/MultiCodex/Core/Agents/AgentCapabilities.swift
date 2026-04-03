import Foundation

struct AgentCapabilities: Equatable {
    let supportsUsage: Bool
    let supportsInAppLogin: Bool
    let supportsTerminalLogin: Bool
    let supportsImportFromDefaultAuth: Bool
    let supportsStatusCheck: Bool
    let supportsAutoSwitching: Bool

    static let codex = AgentCapabilities(
        supportsUsage: true,
        supportsInAppLogin: true,
        supportsTerminalLogin: true,
        supportsImportFromDefaultAuth: true,
        supportsStatusCheck: true,
        supportsAutoSwitching: true
    )

    static let pi = AgentCapabilities(
        supportsUsage: false,
        supportsInAppLogin: false,
        supportsTerminalLogin: true,
        supportsImportFromDefaultAuth: true,
        supportsStatusCheck: true,
        supportsAutoSwitching: false
    )
}
