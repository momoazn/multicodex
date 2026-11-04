import Foundation

/// Creates and manages isolated CODEX_HOME directories for each account.
enum ManagedCodexHomeFactory {
    /// Root URL scoped to a specific multicodex home directory.
    /// Use this when managed homes should be owned by a particular config.
    static func scopedRootURL(multicodexHome: String) -> URL {
        URL(fileURLWithPath: multicodexHome)
            .appendingPathComponent("managed-homes", isDirectory: true)
    }

    /// Scoped variant: get the managed home URL under a specific multicodex home.
    static func homeURL(for accountName: String, multicodexHome: String) -> URL? {
        let sanitized = sanitize(accountName)
        let homeURL = scopedRootURL(multicodexHome: multicodexHome)
            .appendingPathComponent(sanitized, isDirectory: true)
        return FileManager.default.fileExists(atPath: homeURL.path) ? homeURL : nil
    }

    /// Scoped variant: create a managed home under a specific multicodex home.
    static func createHome(for accountName: String, multicodexHome: String) throws -> URL {
        let sanitized = sanitize(accountName)
        let homeURL = scopedRootURL(multicodexHome: multicodexHome)
            .appendingPathComponent(sanitized, isDirectory: true)

        try FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)

        let sessionsURL = homeURL.appendingPathComponent("sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsURL, withIntermediateDirectories: true)

        return homeURL
    }

    static func readAuthData(from homeURL: URL) throws -> Data? {
        let authURL = homeURL.appendingPathComponent("auth.json")
        guard FileManager.default.fileExists(atPath: authURL.path) else { return nil }
        return try Data(contentsOf: authURL)
    }

    static func writeAuthData(_ data: Data, to homeURL: URL) throws {
        try FileManager.default.createDirectory(at: homeURL, withIntermediateDirectories: true)
        let authURL = homeURL.appendingPathComponent("auth.json")
        try data.write(to: authURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: Int16(0o600))],
            ofItemAtPath: authURL.path
        )
    }

    static func sanitize(_ name: String) -> String {
        name.components(separatedBy: .init(charactersIn: "/\\:*?\"<>|")).joined()
    }
}
