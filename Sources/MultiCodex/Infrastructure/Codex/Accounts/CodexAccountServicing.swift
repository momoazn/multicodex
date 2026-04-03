import Foundation

extension CodexAccountService: CodingAgentServicing {
    var agentKind: AgentKind { .codex }
    var capabilities: AgentCapabilities { .codex }

    var customRuntimePath: String? {
        get { customCodexPath }
        set { customCodexPath = newValue }
    }
}
