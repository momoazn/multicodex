import AppKit
import SwiftUI

// MARK: - Header

extension AccountsMenuContentView {
    var header: some View {
        HStack(alignment: .center, spacing: 10) {
            AccountAvatar(
                name: viewModel.currentAccount?.name ?? "M",
                color: DashboardTokens.accent,
                size: 32
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(viewModel.currentAccount?.name ?? "MultiCodex")
                        .font(DashboardTokens.Font.title())
                        .foregroundStyle(DashboardTokens.textPrimary)
                        .lineLimit(1)

                    if viewModel.currentAccount != nil {
                        AccountStatusPill(text: "Active", color: DashboardTokens.accent)
                    }
                }

                // Re-render every 30 s so "Updated ..." does not go stale while the menu is open.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(headerSummaryText(now: context.date))
                        .font(DashboardTokens.Font.metadata())
                        .foregroundStyle(DashboardTokens.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 6) {
                if viewModel.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(DashboardTokens.accent)
                        .accessibilityLabel("Refreshing")
                }

                ActionPillButton(
                    title: "Refresh",
                    symbol: "arrow.clockwise",
                    role: .secondary,
                    layout: .iconOnly,
                    isDisabled: viewModel.isRefreshing
                ) {
                    viewModel.refreshLive()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .help("Refresh usage (⌘R)")

                ActionPillButton(
                    title: "Settings",
                    symbol: "gearshape.fill",
                    role: .secondary,
                    layout: .iconOnly
                ) {
                    openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: [.command])
                .help("Open Settings (⌘,)")
            }
        }
        .cardStyle(fill: DashboardTokens.cardBackgroundSubtle, hasGlass: true)
    }
}

// MARK: - Sort Menu

extension AccountsMenuContentView {
    /// One compact menu replaces three full-width pickers.
    var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: Binding(
                get: { viewModel.accountSortCriterion },
                set: { viewModel.setAccountSortCriterion($0) }
            )) {
                ForEach(AccountSortCriterion.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.inline)

            if viewModel.accountSortCriterion != .name {
                Picker("Window", selection: Binding(
                    get: { viewModel.accountSortWindow },
                    set: { viewModel.setAccountSortWindow($0) }
                )) {
                    ForEach(AccountSortWindow.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            }

            Picker("Order", selection: Binding(
                get: { viewModel.accountSortDirection },
                set: { viewModel.setAccountSortDirection($0) }
            )) {
                Text("High to low").tag(SortDirection.descending)
                Text("Low to high").tag(SortDirection.ascending)
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(DashboardTokens.Font.caption())
                Text(sortSummaryText)
                    .font(DashboardTokens.Font.metadata().weight(.medium))
            }
            .foregroundStyle(DashboardTokens.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort accounts")
        .accessibilityLabel("Sort accounts")
        .accessibilityValue(sortSummaryText)
    }

    private var sortSummaryText: String {
        let arrow = viewModel.accountSortDirection == .descending ? "↓" : "↑"
        if viewModel.accountSortCriterion == .name {
            return "Name \(arrow)"
        }
        return "\(viewModel.accountSortCriterion.title) · \(viewModel.accountSortWindow.title) \(arrow)"
    }
}

// MARK: - Alert Banner

extension AccountsMenuContentView {
    func alertBanner(_ alert: MenuAlertState) -> some View {
        AlertActionCard(
            alert: alert,
            isDisabled: isActionBusy,
            action: { performAlertAction(alert) },
            secondaryAction: alert.secondaryAction.map { action in
                { performAlertAction(MenuAlertState(severity: alert.severity, title: alert.title, message: alert.message, actionTitle: alert.secondaryActionTitle ?? "", action: action)) }
            }
        )
    }
}

// MARK: - Usage Section (Bento)

extension AccountsMenuContentView {
    var bentoUsageSection: some View {
        VStack(alignment: .leading, spacing: DashboardTokens.Spacing.cardGap) {
            if let current = viewModel.currentAccount {
                HStack(spacing: DashboardTokens.Spacing.cardGap) {
                    usageCard(title: "5-hour limit", metric: current.usage.fiveHour)
                    usageCard(title: "Weekly limit", metric: current.usage.weekly)
                }
            }
        }
    }

    /// The ring shows one side (left or used); the text shows the other, so nothing repeats.
    private func complementText(for metric: UsageMetric, isRemaining: Bool) -> String {
        guard let used = metric.usedPercent else { return "No data" }
        let clamped = min(100, max(0, used))
        return isRemaining ? "\(Int(clamped.rounded()))% used" : "\(Int((100 - clamped).rounded()))% left"
    }

    private func usageCard(title: String, metric: UsageMetric) -> some View {
        let isRemaining = viewModel.usageBarStyle == .depleting
        let tone = AccountPresentation.usageColor(for: metric)
        let valueText = viewModel.displayPercentText(for: metric)

        return HStack(spacing: 12) {
            DashboardProgressRing(
                progress: viewModel.progressValue(for: metric),
                color: tone,
                label: isRemaining ? "LEFT" : "USED",
                valueText: valueText,
                size: 56,
                expandHorizontally: false
            )

            VStack(alignment: .leading, spacing: 3) {
                DashboardSectionHeader(title: title)
                Text(complementText(for: metric, isRemaining: isRemaining))
                    .font(DashboardTokens.Font.cardHeading())
                    .foregroundStyle(DashboardTokens.textPrimary)
                    .monospacedDigit()
                Text(metric.resetText(mode: viewModel.resetDisplayMode))
                    .font(DashboardTokens.Font.metadata())
                    .foregroundStyle(DashboardTokens.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(fill: DashboardTokens.cardBackgroundElevated, hasGlass: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) for current account")
    }
}

// MARK: - Runtime Status Panel

extension AccountsMenuContentView {
    private var runtimeStatusPanel: some View {
        HStack(spacing: 8) {
            Image(systemName: runtimeStatus.symbol)
                .font(DashboardTokens.Font.metadataBold())
                .foregroundStyle(runtimeStatus.color)

            Text(runtimeStatus.text)
                .font(DashboardTokens.Font.metadata())
                .foregroundStyle(DashboardTokens.textSecondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: DashboardTokens.Spacing.controlRadius, style: .continuous)
                .fill(runtimeStatus.color.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardTokens.Spacing.controlRadius, style: .continuous)
                .stroke(runtimeStatus.color.opacity(0.14), lineWidth: 0.5)
        )
    }
}

// MARK: - Accounts Section

extension AccountsMenuContentView {
    var accountsSection: some View {
        VStack(alignment: .leading, spacing: DashboardTokens.Spacing.cardGap) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    DashboardSectionHeader(title: viewModel.currentAccount == nil ? "Accounts" : "Other accounts")
                    accountsSummaryLine
                }

                Spacer()

                sortMenu

                ActionPillButton(
                    title: areAllAccountsExpanded ? "Collapse All" : "Expand All",
                    symbol: areAllAccountsExpanded ? "rectangle.compress.vertical" : "rectangle.expand.vertical",
                    role: .secondary,
                    layout: .iconOnly
                ) {
                    toggleAllAccountsExpanded()
                }
                .help(areAllAccountsExpanded ? "Collapse all" : "Expand all")
            }

            if shouldScrollAccountsList {
                ScrollView(.vertical, showsIndicators: false) {
                    accountsRowsList
                }
                .frame(height: accountsListScrollHeight)
            } else {
                accountsRowsList
            }
        }
        .cardStyle(fill: DashboardTokens.cardBackgroundElevated, hasGlass: true)
    }

    private var accountsRowsList: some View {
        VStack(spacing: 5) {
            ForEach(visibleRows) { row in
                DashboardAccountRow(
                    row: row,
                    isExpanded: expandedAccountNames.contains(row.name),
                    fiveHourProgressValue: viewModel.progressValue(for: row.account.usage.fiveHour),
                    weeklyProgressValue: viewModel.progressValue(for: row.account.usage.weekly),
                    fiveHourPercentText: viewModel.displayPercentText(for: row.account.usage.fiveHour),
                    weeklyPercentText: viewModel.displayPercentText(for: row.account.usage.weekly),
                    isBusy: isActionBusy,
                    isSwitching: viewModel.switchingAccountName == row.name,
                    isAuthRunning: viewModel.accountActionInFlightName == row.name || viewModel.loginInFlightName == row.name,
                    canCancelLogin: viewModel.canCancelLogin(for: row.name),
                    canRemovePendingLogin: viewModel.canRemovePendingLogin(for: row.name),
                    onActivate: { performPrimaryAction(for: row) },
                    onCancelLogin: {
                        viewModel.cancelLogin(
                            for: row.name,
                            removeCreatedAccount: viewModel.canRemovePendingLogin(for: row.name)
                        )
                    },
                    onRowTap: { toggleAccountDisclosure(row.name) },
                    onToggleExpanded: { toggleAccountDisclosure(row.name) }
                )
            }
        }
    }

    private var accountsListMaxHeight: CGFloat {
        let screenHeight = NSScreen.main?.visibleFrame.height ?? 820
        return min(680, max(480, screenHeight - 180))
    }

    private var accountsListScrollHeight: CGFloat {
        min(accountsListMaxHeight, max(320, estimatedAccountsListHeight))
    }

    private var shouldScrollAccountsList: Bool {
        estimatedAccountsListHeight > accountsListMaxHeight
    }

    private var estimatedAccountsListHeight: CGFloat {
        let rows = visibleRows
        guard !rows.isEmpty else { return 0 }

        let rowHeights = rows.reduce(CGFloat(0)) { total, row in
            total + (expandedAccountNames.contains(row.name) ? 118 : 58)
        }
        let gaps = CGFloat(max(0, rows.count - 1)) * 5
        return rowHeights + gaps
    }
}

// MARK: - Empty State

extension AccountsMenuContentView {
    var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((viewModel.isCodexRuntimeAvailable ? DashboardTokens.accent : DashboardTokens.statusOrange).opacity(0.14))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: viewModel.isCodexRuntimeAvailable ? "person.crop.circle.badge.plus" : "exclamationmark.triangle")
                            .font(DashboardTokens.Font.headline())
                            .foregroundStyle(viewModel.isCodexRuntimeAvailable ? DashboardTokens.accent : DashboardTokens.statusOrange)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    DashboardSectionHeader(title: "Getting Started")
                    Text(viewModel.isCodexRuntimeAvailable ? "Add your first account" : "Finish runtime setup")
                        .font(DashboardTokens.Font.detailTitle())
                        .foregroundStyle(DashboardTokens.textPrimary)
                }
            }

            Text(onboardingCopy)
                .font(DashboardTokens.Font.metadata())
                .foregroundStyle(DashboardTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            runtimeStatusPanel

            HStack(spacing: DashboardTokens.Spacing.footerSpacing) {
                ActionPillButton(
                    title: viewModel.isCodexRuntimeAvailable ? "Log In First Account" : "Open Runtime Settings",
                    symbol: viewModel.isCodexRuntimeAvailable ? "person.crop.circle.badge.plus" : "terminal",
                    role: .primary,
                    isDisabled: isActionBusy
                ) {
                    if viewModel.isCodexRuntimeAvailable {
                        viewModel.startNewAccountLogin()
                    } else {
                        viewModel.selectSettingsSection(.system)
                        openSettingsWindow()
                    }
                }

                if !viewModel.isCodexRuntimeAvailable {
                    ActionPillButton(title: "Refresh Runtime", symbol: "arrow.clockwise") {
                        viewModel.refreshLive()
                    }
                }
            }
        }
        .cardStyle(fill: DashboardTokens.cardBackgroundElevated, hasGlass: true)
    }
}

// MARK: - Loading State

extension AccountsMenuContentView {
    var loadingStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DashboardTokens.accentBackground)
                    .frame(width: 30, height: 30)
                    .overlay(
                        ProgressView()
                            .controlSize(.small)
                            .tint(DashboardTokens.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    DashboardSectionHeader(title: "Loading")
                    Text("Refreshing accounts and usage")
                        .font(DashboardTokens.Font.cardHeading())
                        .foregroundStyle(DashboardTokens.textPrimary)
                }
            }

            Text("Gathering runtime and account state. This usually takes a moment.")
                .font(DashboardTokens.Font.metadata())
                .foregroundStyle(DashboardTokens.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                loadingBar(width: 0.88, height: 8)
                loadingBar(width: 0.72, height: 8)
                loadingBar(width: 0.56, height: 8)
            }
            .accessibilityHidden(true)
        }
        .cardStyle(fill: DashboardTokens.cardBackgroundElevated, hasGlass: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading account data")
        .accessibilityValue("Refreshing accounts and usage")
    }

    private func loadingBar(width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DashboardTokens.cardBorder)
                .frame(width: geometry.size.width * width, height: height)
        }
        .frame(height: height)
    }
}

// MARK: - Footer

extension AccountsMenuContentView {
    var footer: some View {
        HStack(spacing: DashboardTokens.Spacing.footerSpacing) {
            ActionPillButton(
                title: viewModel.accounts.isEmpty ? "Start Login" : "Add Account",
                symbol: "person.crop.circle.badge.plus",
                role: loginNewFooterRole,
                isDisabled: isActionBusy
            ) {
                viewModel.startNewAccountLogin()
            }

            Spacer()

            if hiddenAccountsCount > 0, !viewModel.showAllAccountsInMenu {
                Button("Show \(hiddenAccountsCount) more") {
                    viewModel.setShowAllAccountsInMenu(true)
                }
                .buttonStyle(.plain)
                .font(DashboardTokens.Font.metadata().weight(.medium))
                .foregroundStyle(DashboardTokens.accentSoft)
            }

            ActionPillButton(
                title: "Quit MultiCodex",
                symbol: "power",
                role: .secondary,
                layout: .iconOnly
            ) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
            .help("Quit MultiCodex (⌘Q)")
        }
        .padding(.top, 2)
    }
}

// MARK: - Computed Values

extension AccountsMenuContentView {
    var visibleRows: [AccountRowState] {
        if viewModel.showAllAccountsInMenu {
            return allRows
        }
        return Array(allRows.prefix(viewModel.preferredMenuAccountCount))
    }

    var allRows: [AccountRowState] {
        viewModel.menuListAccounts.map { account in
            AccountRowState(account: account, resetDisplayMode: viewModel.resetDisplayMode)
        }
    }

    var hiddenAccountsCount: Int {
        max(0, allRows.count - visibleRows.count)
    }

    var loginNewFooterRole: ActionPillRole {
        if viewModel.prioritizedMenuAlert != nil || viewModel.accounts.isEmpty {
            return .primary
        }
        return .secondary
    }

    var onboardingCopy: String {
        switch viewModel.onboardingState.step {
        case .runtime:
            return "Confirm that the Codex runtime is available first. Once healthy, connect your first account and MultiCodex will handle the rest."
        case .login:
            return "Log in once and MultiCodex will immediately start showing usage, headroom, and switching guidance."
        case .verify:
            return "Run a quick status check to verify authentication and finish the setup flow."
        case .done:
            return "Your setup is complete."
        }
    }

    func headerSummaryText(now: Date) -> String {
        if viewModel.accounts.isEmpty {
            return "No accounts yet"
        }
        let updated = viewModel.lastUpdatedLabel(now: now)
        guard let email = viewModel.currentAccount?.workspaceEmailHint else { return updated }
        return "\(email) \u{2022} \(updated)"
    }

    /// "4 of 5 ready · 2 low · next reset 46 min", colored by severity.
    var accountsSummaryLine: some View {
        let health = AccountsHealthSummary.from(viewModel.accounts)
        var line = Text("\(health.healthyAccounts) of \(health.totalAccounts) ready")
            .foregroundColor(DashboardTokens.textSecondary)
        if health.atRiskAccounts > 0 {
            line = line
                + Text(" \u{00B7} ").foregroundColor(DashboardTokens.textTertiary)
                + Text("\(health.atRiskAccounts) running low").foregroundColor(DashboardTokens.statusOrange)
        }
        if hiddenAccountsCount > 0, !viewModel.showAllAccountsInMenu {
            line = line
                + Text(" \u{00B7} ").foregroundColor(DashboardTokens.textTertiary)
                + Text("showing \(visibleRows.count) of \(allRows.count)").foregroundColor(DashboardTokens.textTertiary)
        }
        return line
            .font(DashboardTokens.Font.metadata())
            .lineLimit(1)
    }
}

// MARK: - Actions

extension AccountsMenuContentView {
    func performAlertAction(_ alert: MenuAlertState) {
        switch alert.action {
        case .openRuntimeSettings:
            viewModel.selectSettingsSection(.system)
            openSettingsWindow()
        default:
            viewModel.performMenuAlertAction(alert.action)
        }
    }

    func performPrimaryAction(for row: AccountRowState) {
        switch row.primaryAction {
        case .switchAccount:
            guard !isSwitchBusy else { return }
            viewModel.switchToAccount(named: row.name)
        case .relogin:
            guard !isLoginBusy else { return }
            viewModel.openLoginInTerminal(for: row.name)
        case .none:
            toggleExpanded(row.name)
        }
    }

    var activeToast: (text: String, color: Color)? {
        if let error = viewModel.accountActionError {
            return (error, DashboardTokens.statusRed)
        }
        if let message = viewModel.accountActionMessage {
            return (message, DashboardTokens.accentSoft)
        }
        return nil
    }

    func toastView(text: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.40), radius: 3, y: 0)

            Text(text)
                .font(DashboardTokens.Font.metadata().weight(.semibold))
                .foregroundStyle(DashboardTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.canCancelLogin {
                ActionPillButton(
                    title: "Cancel Login",
                    symbol: "xmark.circle",
                    layout: .iconOnly
                ) {
                    viewModel.cancelLogin()
                }
                .help("Cancel login")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DashboardTokens.Spacing.controlRadius, style: .continuous)
                    .fill(DashboardTokens.cardBackgroundElevated)
                RoundedRectangle(cornerRadius: DashboardTokens.Spacing.controlRadius, style: .continuous)
                    .fill(DashboardTokens.glassHighlight)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DashboardTokens.Spacing.controlRadius, style: .continuous)
                .stroke(color.opacity(0.28), lineWidth: 0.5)
        )
        .shadow(color: DashboardTokens.shadowSubtle, radius: 8, y: 4)
    }

    var isSwitchBusy: Bool {
        !viewModel.canStartSwitchAction
    }

    var isLoginBusy: Bool {
        !viewModel.canStartLoginAction
    }

    var isActionBusy: Bool {
        !viewModel.canStartMaintenanceAccountAction
    }

    var runtimeStatus: RuntimeStatusPresentation {
        AccountPresentation.runtimeStatus(
            summary: viewModel.runtimeProbeSummary,
            isAvailable: viewModel.isCodexRuntimeAvailable
        )
    }

    func openSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
    }

    func installKeyboardMonitor() {
        guard keyboardMonitor == nil else { return }
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if handleKeyEvent(event) {
                return nil
            }
            return event
        }
    }

    func removeKeyboardMonitor() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
    }

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == [.command], event.charactersIgnoringModifiers?.lowercased() == "r" {
            viewModel.refreshLive()
            return true
        }
        if modifiers == [.command], event.charactersIgnoringModifiers == "," {
            openSettingsWindow()
            return true
        }
        if modifiers == [.command], event.charactersIgnoringModifiers?.lowercased() == "q" {
            NSApp.terminate(nil)
            return true
        }
        return false
    }

    func toggleExpanded(_ accountName: String) {
        if expandedAccountNames.contains(accountName) {
            expandedAccountNames.remove(accountName)
        } else {
            expandedAccountNames.insert(accountName)
        }
    }

    func toggleAccountDisclosure(_ accountName: String) {
        toggleExpanded(accountName)
    }

    var areAllAccountsExpanded: Bool {
        let visibleNames = Set(visibleRows.map(\.name))
        guard !visibleNames.isEmpty else { return false }
        return visibleNames.isSubset(of: expandedAccountNames)
    }

    func toggleAllAccountsExpanded() {
        let visibleNames = Set(visibleRows.map(\.name))
        if areAllAccountsExpanded {
            expandedAccountNames.subtract(visibleNames)
        } else {
            expandedAccountNames.formUnion(visibleNames)
        }
    }

}
