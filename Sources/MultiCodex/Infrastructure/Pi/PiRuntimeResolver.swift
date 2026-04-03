import Foundation

struct PiRuntimeDescriptor {
    let executableURL: URL
    let prefixArguments: [String]
    let display: String
}

enum PiRuntimeResolver {
    static func resolve(
        customRuntimePath: String?,
        fileManager: FileManager,
        environment: [String: String]
    ) throws -> PiRuntimeDescriptor {
        func runtimeForRaw(_ raw: String, source: String) throws -> PiRuntimeDescriptor {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw PiAgentServiceError(message: "Empty runtime value for \(source).")
            }
            if trimmed.contains("/") {
                let expanded = (trimmed as NSString).expandingTildeInPath
                guard fileManager.isExecutableFile(atPath: expanded) else {
                    throw PiAgentServiceError(message: "Configured pi executable is not executable: \(expanded)")
                }
                return PiRuntimeDescriptor(
                    executableURL: URL(fileURLWithPath: expanded),
                    prefixArguments: [],
                    display: "\(expanded) [\(source)]"
                )
            }
            return PiRuntimeDescriptor(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                prefixArguments: [trimmed],
                display: "\(trimmed) (from PATH, \(source))"
            )
        }

        func runtimeForDetectedExecutable(_ path: String, source: String?) -> PiRuntimeDescriptor {
            PiRuntimeDescriptor(
                executableURL: URL(fileURLWithPath: path),
                prefixArguments: [],
                display: source.map { "\(path) (\($0))" } ?? path
            )
        }

        if let customRuntimePath, !customRuntimePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try runtimeForRaw(customRuntimePath, source: "custom")
        }

        if let envRaw = environment["MULTICODEX_PI"], !envRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return try runtimeForRaw(envRaw, source: "MULTICODEX_PI")
        }

        let pathValue = ExecutableSearchPath.environment(from: environment)["PATH"]
        for pathEntry in ExecutableSearchPath.components(from: pathValue) {
            let expandedEntry = (pathEntry as NSString).expandingTildeInPath
            let candidate = (expandedEntry as NSString).appendingPathComponent("pi")
            if fileManager.isExecutableFile(atPath: candidate) {
                return runtimeForDetectedExecutable(candidate, source: "from PATH scan")
            }
        }

        for path in ["/opt/homebrew/bin/pi", "/usr/local/bin/pi", "/usr/bin/pi"] where fileManager.isExecutableFile(atPath: path) {
            return runtimeForDetectedExecutable(path, source: nil)
        }

        return PiRuntimeDescriptor(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            prefixArguments: ["pi"],
            display: "pi (from PATH)"
        )
    }
}
