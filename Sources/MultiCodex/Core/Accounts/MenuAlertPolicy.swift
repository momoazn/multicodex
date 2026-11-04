import Foundation

enum MenuAlertPolicy {
    static func prioritizedAlert(
        isRuntimeAvailable: Bool,
        runtimeSummary: String?,
        lastRefreshError: String?,
        accountsNeedingLogin: [AccountUsage]
    ) -> MenuAlertState? {
        if !isRuntimeAvailable {
            return MenuAlertState(
                severity: .runtimeUnavailable,
                title: "Codex runtime unavailable",
                message: runtimeSummary ?? "Set the runtime path in Settings.",
                actionTitle: "Open Runtime Settings",
                action: .openRuntimeSettings
            )
        }

        if let lastRefreshError {
            return MenuAlertState(
                severity: .refreshError,
                title: "Refresh failed",
                message: lastRefreshError,
                actionTitle: "Try Again",
                action: .refreshLive
            )
        }

        if let accountNeedingLogin = accountsNeedingLogin.first {
            return MenuAlertState(
                severity: .authRequired,
                title: "\(accountNeedingLogin.name) needs login",
                message: "Its session expired. Log in again to see usage and switch to it.",
                actionTitle: "Log In",
                action: .relogin(accountName: accountNeedingLogin.name)
            )
        }

        return nil
    }
}
