import Foundation

enum RateLimitsRPCClient {
    static func writeMessage(_ payload: [String: Any], to handle: FileHandle) throws {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        // The throwing API reports a closed pipe as an error; write(_:) raises an
        // Objective-C exception there and crashes the app when codex exits early.
        try handle.write(contentsOf: data + Data("\n".utf8))
    }
}
