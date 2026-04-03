import Foundation

struct CodingAgentRegistry {
    private let servicesByKind: [AgentKind: any CodingAgentServicing]

    init(services: [any CodingAgentServicing]) {
        var servicesByKind: [AgentKind: any CodingAgentServicing] = [:]
        for service in services {
            servicesByKind[service.agentKind] = service
        }
        self.servicesByKind = servicesByKind
    }

    func service(for kind: AgentKind) -> (any CodingAgentServicing)? {
        servicesByKind[kind]
    }

    var supportedAgents: [AgentKind] {
        AgentKind.allCases.filter { servicesByKind[$0] != nil }
    }
}
