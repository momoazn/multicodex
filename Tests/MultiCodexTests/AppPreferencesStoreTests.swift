import XCTest
@testable import MultiCodex

final class AppPreferencesStoreTests: XCTestCase {
    func testCustomCodexPathDefaultsToEmptyWhenUnset() {
        let defaults = ephemeralDefaults()

        let store = AppPreferencesStore(defaults: defaults)
        XCTAssertEqual(store.customCodexPath, "")
    }

    func testSelectedSettingsAccountDefaultsToNilWhenUnset() {
        let defaults = ephemeralDefaults()

        let store = AppPreferencesStore(defaults: defaults)
        XCTAssertNil(store.selectedSettingsAccountName)
    }

    func testSettingCustomCodexPathPersistsCanonicalKey() {
        let defaults = ephemeralDefaults()

        var store = AppPreferencesStore(defaults: defaults)
        store.customCodexPath = "/usr/local/bin/codex"

        XCTAssertEqual(defaults.string(forKey: AppPreferencesStore.Keys.customCodexPath), "/usr/local/bin/codex")
    }

    func testSelectedAgentDefaultsToCodexAndPersists() {
        let defaults = ephemeralDefaults()
        var store = AppPreferencesStore(defaults: defaults)

        XCTAssertEqual(store.selectedAgent, .codex)

        store.selectedAgent = .pi

        let persisted = AppPreferencesStore(defaults: defaults)
        XCTAssertEqual(persisted.selectedAgent, .pi)
    }

    func testRuntimePathForCodexFallsBackToLegacyKey() {
        let defaults = ephemeralDefaults()
        defaults.set("/legacy/codex", forKey: AppPreferencesStore.Keys.customCodexPath)

        let store = AppPreferencesStore(defaults: defaults)
        XCTAssertEqual(store.runtimePath(for: .codex), "/legacy/codex")
    }

    func testRuntimePathPersistsPerAgent() {
        let defaults = ephemeralDefaults()
        let store = AppPreferencesStore(defaults: defaults)

        store.setRuntimePath("/usr/local/bin/codex", for: .codex)
        store.setRuntimePath("/usr/local/bin/pi", for: .pi)

        let persisted = AppPreferencesStore(defaults: defaults)
        XCTAssertEqual(persisted.runtimePath(for: .codex), "/usr/local/bin/codex")
        XCTAssertEqual(persisted.runtimePath(for: .pi), "/usr/local/bin/pi")
    }

    func testDefaultsForDisplaySettings() {
        let defaults = ephemeralDefaults()
        var store = AppPreferencesStore(defaults: defaults)

        XCTAssertEqual(store.resetDisplayMode, .relative)
        XCTAssertEqual(store.menuDensity, .compact)
        XCTAssertEqual(store.usageBarStyle, .depleting)
        XCTAssertEqual(store.accountSwitchingStrategy, .manual)
        XCTAssertFalse(store.autoSwitchNotificationsEnabled)

        store.resetDisplayMode = .absolute
        store.menuDensity = .comfortable
        store.usageBarStyle = .filling
        store.accountSwitchingStrategy = .expiryAware
        store.autoSwitchNotificationsEnabled = true

        let persisted = AppPreferencesStore(defaults: defaults)
        XCTAssertEqual(persisted.resetDisplayMode, .absolute)
        XCTAssertEqual(persisted.menuDensity, .comfortable)
        XCTAssertEqual(persisted.usageBarStyle, .filling)
        XCTAssertEqual(persisted.accountSwitchingStrategy, .expiryAware)
        XCTAssertTrue(persisted.autoSwitchNotificationsEnabled)
    }

    private func ephemeralDefaults() -> UserDefaults {
        let suite = "MultiCodexTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("Could not create isolated UserDefaults suite: \(suite)")
            return .standard
        }
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
