import SwiftUI

struct DashboardAccountRow: View {
    let row: AccountRowState
    let isExpanded: Bool
    let fiveHourProgressValue: Double
    let weeklyProgressValue: Double
    let fiveHourPercentText: String
    let weeklyPercentText: String
    let isBusy: Bool
    let isSwitching: Bool
    let isAuthRunning: Bool
    let canCancelLogin: Bool
    let canRemovePendingLogin: Bool
    let onActivate: () -> Void
    let onCancelLogin: () -> Void
    let onRowTap: () -> Void
    let onToggleExpanded: () -> Void
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived State

    private var isPrimaryActionInProgress: Bool {
        switch row.primaryAction {
        case .switchAccount: return isSwitching
        case .relogin: return isAuthRunning
        case .none: return false
        }
    }

    private var activationHelpText: String {
        switch row.primaryAction {
        case .switchAccount: return "Switch to this account"
        case .relogin: return "Log in to this account again"
        case .none: return "Current account"
        }
    }

    private var activationSymbol: String {
        switch row.primaryAction {
        case .switchAccount: return "arrow.left.arrow.right"
        case .relogin: return "arrow.triangle.2.circlepath"
        case .none: return "checkmark"
        }
    }

    private var isActivationDisabled: Bool {
        isBusy && row.primaryAction != .none
    }

    private var rowBackgroundColor: Color {
        if row.isCurrent {
            return DashboardTokens.accentBackground.opacity(isHovered ? 0.52 : 0.40)
        }
        if row.primaryAction == .relogin {
            return DashboardTokens.statusOrange.opacity(isHovered ? 0.12 : 0.08)
        }
        return isHovered ? DashboardTokens.hoverOverlay : DashboardTokens.cardBackgroundSubtle
    }

    private var rowBorderColor: Color {
        if row.isCurrent {
            return DashboardTokens.accent.opacity(isHovered ? 0.34 : 0.26)
        }
        if row.primaryAction == .relogin {
            return DashboardTokens.statusOrange.opacity(isHovered ? 0.28 : 0.20)
        }
        return isHovered ? DashboardTokens.hoverBorder : DashboardTokens.cardBorder
    }

    private var connectionLabel: String? {
        switch row.primaryAction {
        case .relogin: return "Needs login"
        case .switchAccount: return nil
        case .none: return row.isCurrent ? "Active" : row.account.connectionState.label
        }
    }

    private var avatarColor: Color {
        switch row.primaryAction {
        case .relogin: return DashboardTokens.statusOrange
        case .none: return DashboardTokens.accent
        case .switchAccount: return DashboardTokens.accentSoft
        }
    }

    private var subtitleText: String {
        if row.primaryAction == .relogin {
            return "Session expired. Log in again."
        }
        return row.workspaceEmailHint ?? row.resetText
    }

    private var accessibilitySummary: String {
        var parts = [row.name]
        if let connectionLabel { parts.append(connectionLabel) }
        if row.account.connectionState == .connected {
            parts.append("5-hour \(fiveHourPercentText)")
            parts.append("weekly \(weeklyPercentText)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                activationButton

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(row.name)
                                .font(DashboardTokens.Font.accountName())
                                .foregroundStyle(DashboardTokens.textPrimary)
                                .lineLimit(1)

                            if let connectionLabel {
                                AccountStatusPill(text: connectionLabel, color: avatarColor)
                            }
                        }

                        Text(subtitleText)
                            .font(DashboardTokens.Font.metadata())
                            .foregroundStyle(row.primaryAction == .relogin ? DashboardTokens.statusOrange.opacity(0.9) : DashboardTokens.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 6)

                    if !isExpanded, row.account.connectionState == .connected {
                        VStack(alignment: .trailing, spacing: 5) {
                            compactMeter(label: "5h", metric: row.account.usage.fiveHour, valueText: fiveHourPercentText, progress: fiveHourProgressValue)
                            compactMeter(label: "wk", metric: row.account.usage.weekly, valueText: weeklyPercentText, progress: weeklyProgressValue)
                        }
                        .accessibilityHidden(true)
                    }

                    if canCancelLogin {
                        cancelLoginButton
                    }

                    Image(systemName: "chevron.down")
                        .font(DashboardTokens.Font.chevron())
                        .foregroundStyle(DashboardTokens.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .help(primaryAreaHelpText)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(isExpanded ? "Collapse details" : "Expand details")
            }

            expandedDisclosure
        }
        .padding(.horizontal, DashboardTokens.Spacing.rowHPadding)
        .padding(.vertical, DashboardTokens.Spacing.rowVPadding)
        .background(
            RoundedRectangle(cornerRadius: DashboardTokens.Spacing.rowRadius, style: .continuous)
                .fill(rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardTokens.Spacing.rowRadius, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: DashboardTokens.Spacing.rowRadius, style: .continuous))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onRowTap()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text(isExpanded ? "Collapse details" : "Expand details")) {
            onToggleExpanded()
        }
    }

    // MARK: - Compact Meter (collapsed)

    private func compactMeter(label: String, metric: UsageMetric, valueText: String, progress: Double) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(DashboardTokens.Font.captionRegular())
                .foregroundStyle(DashboardTokens.textTertiary)
            UsageMeterBar(progress: progress, color: AccountPresentation.usageColor(for: metric), height: 4)
                .frame(width: 44)
            Text(valueText)
                .font(DashboardTokens.Font.caption())
                .foregroundStyle(UsageLevel.from(usedPercent: metric.usedPercent) == .normal
                    ? DashboardTokens.textPrimary
                    : AccountPresentation.usageColor(for: metric))
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Activation Button

    private var primaryAreaHelpText: String {
        switch row.primaryAction {
        case .switchAccount:
            return "Click to show details. Click the avatar to switch."
        case .relogin:
            return "Click to show details. Click the avatar to log in again."
        case .none:
            return "Current account. Click to show usage details."
        }
    }

    /// Avatar initial; on hover it shows what a click does (switch or re-login).
    private var activationButton: some View {
        Button(action: onActivate) {
            ZStack {
                if isPrimaryActionInProgress {
                    Circle().fill(avatarColor.opacity(0.16))
                    ProgressView()
                        .controlSize(.small)
                        .tint(avatarColor)
                } else if isHovered, row.primaryAction != .none, !isActivationDisabled {
                    Circle().fill(avatarColor.opacity(0.24))
                    Circle().stroke(avatarColor.opacity(0.6), lineWidth: 0.5)
                    Image(systemName: activationSymbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(avatarColor)
                } else {
                    AccountAvatar(name: row.name, color: avatarColor, size: 28)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(isActivationDisabled)
        .opacity(isActivationDisabled ? 0.48 : 1)
        .accessibilityLabel(activationHelpText)
        .accessibilityValue(isPrimaryActionInProgress ? "In progress" : "")
        .help(activationHelpText)
        .contentShape(Circle())
    }

    private var cancelLoginButton: some View {
        Button(action: onCancelLogin) {
            Label(canRemovePendingLogin ? "Cancel and Remove" : "Cancel Login", systemImage: canRemovePendingLogin ? "trash.circle.fill" : "xmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(DashboardTokens.Font.metadataBold())
                .foregroundStyle(DashboardTokens.statusRed)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(DashboardTokens.statusRed.opacity(0.12))
                )
                .overlay(
                    Circle()
                        .stroke(DashboardTokens.statusRed.opacity(0.34), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help(canRemovePendingLogin ? "Cancel login and remove this account" : "Cancel login")
        .accessibilityLabel(canRemovePendingLogin ? "Cancel login and remove account" : "Cancel login")
        .contentShape(Circle())
    }

    // MARK: - Expanded Content

    private var expandedDisclosure: some View {
        Group {
            if isExpanded {
                expandedContent
                    .padding(.top, 12)
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if row.account.connectionState == .connected {
                VStack(alignment: .leading, spacing: 8) {
                    expandedMetricBar(
                        label: "5-hour",
                        metric: row.account.usage.fiveHour,
                        valueText: fiveHourPercentText,
                        resetText: row.resetText,
                        progress: fiveHourProgressValue
                    )
                    expandedMetricBar(
                        label: "Weekly",
                        metric: row.account.usage.weekly,
                        valueText: weeklyPercentText,
                        resetText: row.account.usage.weekly.resetText(mode: row.resetDisplayMode),
                        progress: weeklyProgressValue
                    )
                }
            }

            expandedDetailFooter
        }
    }

    private func expandedMetricBar(
        label: String,
        metric: UsageMetric,
        valueText: String,
        resetText: String,
        progress: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(label)
                    .font(DashboardTokens.Font.caption())
                    .foregroundStyle(DashboardTokens.textTertiary)
                Text(valueText)
                    .font(DashboardTokens.Font.metadata().weight(.semibold))
                    .foregroundStyle(DashboardTokens.textPrimary)
                    .monospacedDigit()

                Spacer(minLength: 8)

                Text(resetText)
                    .font(DashboardTokens.Font.metadata())
                    .foregroundStyle(DashboardTokens.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            UsageMeterBar(progress: progress, color: AccountPresentation.usageColor(for: metric), height: 5)
        }
        .accessibilityElement(children: .combine)
    }

    private var expandedDetailFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let paceText = row.account.paceSummary {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle()
                        .fill(paceColor(row.account.fiveHourPace?.stage))
                        .frame(width: 6, height: 6)
                    Text(paceText)
                        .font(DashboardTokens.Font.metadata())
                        .foregroundStyle(DashboardTokens.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .center, spacing: 8) {
                // The email is already in the row subtitle.
                Spacer(minLength: 6)

                switch row.primaryAction {
                case .switchAccount:
                    ActionPillButton(title: "Switch", symbol: "arrow.left.arrow.right", role: .primary, isDisabled: isActivationDisabled, action: onActivate)
                case .relogin:
                    ActionPillButton(title: "Log In Again", symbol: "arrow.triangle.2.circlepath", role: .primary, isDisabled: isActivationDisabled, action: onActivate)
                case .none:
                    EmptyView()
                }
            }
        }
    }

    private func paceColor(_ stage: UsagePace.Stage?) -> Color {
        guard let stage else { return DashboardTokens.textTertiary }
        switch stage {
        case .onTrack, .slightlyBehind, .behind, .farBehind:
            return DashboardTokens.accent
        case .slightlyAhead:
            return DashboardTokens.statusOrange
        case .ahead, .farAhead:
            return DashboardTokens.statusRed
        }
    }
}
