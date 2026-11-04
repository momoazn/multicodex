import SwiftUI

struct RuntimeStatusPresentation {
    let text: String
    let symbol: String
    let color: Color
}

enum AccountPresentation {
    static func statusColor(for state: AccountConnectionState) -> Color {
        switch state {
        case .connected:
            return DashboardTokens.accentSoft
        case .needsLogin:
            return DashboardTokens.statusOrange
        case .error:
            return DashboardTokens.statusRed
        }
    }

    static func alertColor(for severity: MenuAlertState.Severity) -> Color {
        switch severity {
        case .runtimeUnavailable:
            return DashboardTokens.statusOrange
        case .refreshError:
            return DashboardTokens.statusRed
        case .authRequired, .externalAuth:
            return DashboardTokens.statusOrange
        }
    }

    static func alertSymbol(for severity: MenuAlertState.Severity) -> String {
        switch severity {
        case .runtimeUnavailable:
            return "terminal"
        case .refreshError:
            return "exclamationmark.triangle.fill"
        case .authRequired:
            return "person.crop.circle.badge.exclamationmark"
        case .externalAuth:
            return "person.crop.circle.badge.plus"
        }
    }

    static func runtimeStatus(summary: String?, isAvailable: Bool) -> RuntimeStatusPresentation {
        if isAvailable {
            return RuntimeStatusPresentation(
                text: summary ?? "Codex runtime is available.",
                symbol: "checkmark.circle.fill",
                color: DashboardTokens.accentSoft
            )
        }

        if let summary {
            return RuntimeStatusPresentation(
                text: summary,
                symbol: "exclamationmark.triangle.fill",
                color: DashboardTokens.statusOrange
            )
        }

        return RuntimeStatusPresentation(
            text: "Checking Codex runtime...",
            symbol: "clock",
            color: DashboardTokens.textSecondary
        )
    }
}

// MARK: - Status Pill

struct AccountStatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(DashboardTokens.Font.caption())
            .tracking(0.2)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.26), lineWidth: 0.5)
            )
            .foregroundStyle(color)
    }
}

// MARK: - Warning Row

struct SubtleWarningRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DashboardTokens.Font.metadata().weight(.semibold))
                .foregroundStyle(DashboardTokens.statusOrange)
                .padding(.top, 1)

            Text(text)
                .font(DashboardTokens.Font.metadata())
                .foregroundStyle(DashboardTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            DashboardTokens.statusOrange.opacity(0.08),
            in: RoundedRectangle(cornerRadius: DashboardTokens.Spacing.controlRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardTokens.Spacing.controlRadius, style: .continuous)
                .stroke(DashboardTokens.statusOrange.opacity(0.14), lineWidth: 0.5)
        )
    }
}

// MARK: - Usage Meter

extension AccountPresentation {
    /// One color rule for every usage meter: it uses the used percent, so the color
    /// is the same in "remaining" and "used" bar styles.
    static func usageColor(for metric: UsageMetric) -> Color {
        switch UsageLevel.from(usedPercent: metric.usedPercent) {
        case .critical: return DashboardTokens.statusRed
        case .warning: return DashboardTokens.statusOrange
        case .normal: return DashboardTokens.accent
        }
    }
}

struct UsageMeterBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * CGFloat(min(1, max(0, progress))))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

// MARK: - Avatar

struct AccountAvatar: View {
    let name: String
    let color: Color
    var size: CGFloat = 26

    var body: some View {
        Circle()
            .fill(color.opacity(0.16))
            .overlay(Circle().stroke(color.opacity(0.36), lineWidth: 0.5))
            .overlay(
                Text(name.first.map { String($0).uppercased() } ?? "?")
                    .font(.system(size: size * 0.46, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
