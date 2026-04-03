import SwiftUI

extension SettingsContentView {
    func accountUsageSection(_ account: AccountUsage) -> some View {
        settingsInsetPanel(
            title: "Usage",
            description: "Current usage for this \(viewModel.currentAccountNounSingular)."
        ) {
            HStack(spacing: 10) {
                AccountUsageMetricCard(
                    title: "5h",
                    metric: account.usage.fiveHour,
                    resetDisplayMode: viewModel.resetDisplayMode,
                    progressValue: viewModel.progressValue(for: account.usage.fiveHour)
                )
                AccountUsageMetricCard(
                    title: "weekly",
                    metric: account.usage.weekly,
                    resetDisplayMode: viewModel.resetDisplayMode,
                    progressValue: viewModel.progressValue(for: account.usage.weekly)
                )
            }

            settingsInfoRow(symbol: "clock", text: "Last used \(account.lastUsedLabel)")
        }
    }

    func accountDangerSection(_ account: AccountUsage) -> some View {
        settingsInsetPanel(
            title: "Danger Zone",
            description: "Permanent actions for this \(viewModel.currentAccountNounSingular)."
        ) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Removing a \(viewModel.currentAccountNounSingular) disconnects it from MultiCodex. Deleting data also clears stored files.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Button("Remove \(viewModel.currentAccountNounSingular)", role: .destructive) {
                            viewModel.beginAccountRemoval(named: account.name, deleteData: false)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Remove + delete data", role: .destructive) {
                            viewModel.beginAccountRemoval(named: account.name, deleteData: true)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.top, 8)
            } label: {
                Label("Show destructive actions", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
    }

    var runtimePage: some View {
        SettingsPanelCard {
            VStack(alignment: .leading, spacing: 10) {
                settingsSectionIntro(
                    title: "Runtime",
                    description: "Choose a custom \(viewModel.currentRuntimeName) path or use auto-detect."
                )

                settingsFormRow("Agent") {
                    Picker("Agent", selection: agentBinding) {
                        ForEach(AgentKind.allCases) { agent in
                            Text(agent.title).tag(agent)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                settingsInfoRow(symbol: runtimeStatus.symbol, text: runtimeStatus.text, color: runtimeStatus.color)

                TextField(viewModel.selectedAgent.runtimePathPlaceholder, text: $runtimePathDraft)
                    .textFieldStyle(.roundedBorder)

                if let probe = viewModel.runtimeProbeSummary {
                    Text(probe)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Leave this empty to auto-detect `\(viewModel.currentRuntimeName)` from known paths or from your shell PATH.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ActionPillButton(title: "Save", symbol: "checkmark", role: .primary) {
                        viewModel.updateCustomRuntimePath(runtimePathDraft)
                    }
                    .disabled(normalized(runtimePathDraft) == viewModel.customRuntimePath)

                    ActionPillButton(title: "Choose", symbol: "folder") {
                        viewModel.chooseCustomRuntimePath()
                    }

                    ActionPillButton(title: "Use Auto", symbol: "sparkles") {
                        runtimePathDraft = ""
                        viewModel.clearCustomRuntimePath()
                    }
                    .disabled(viewModel.customRuntimePath.isEmpty)
                }
            }
        }
    }

    var displayPage: some View {
        SettingsPanelCard {
            VStack(alignment: .leading, spacing: 10) {
                settingsSectionIntro(
                    title: "Display",
                    description: "Choose how the menu feels and how usage information is shown."
                )

                settingsInsetPanel(
                    title: "Menu Layout",
                    description: "Controls how dense the menu feels and how reset times are presented."
                ) {
                    settingsFormRow("Density", detail: "Compact shows more at once. Comfortable adds breathing room.") {
                        Picker("Menu density", selection: menuDensityBinding) {
                            ForEach(MenuDensity.allCases) { density in
                                Text(density.title).tag(density)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    settingsFormRow("Reset time style", detail: viewModel.resetDisplayMode.descriptionText) {
                        Picker("Reset time style", selection: resetDisplayModeBinding) {
                            ForEach(ResetDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                if viewModel.supportsUsage {
                    settingsInsetPanel(
                        title: "Usage Indicators",
                        description: "Pick whether the bars emphasize remaining budget or usage consumed."
                    ) {
                        settingsFormRow("Usage bars", detail: viewModel.usageBarStyle.descriptionText) {
                            Picker("Usage bars", selection: usageBarStyleBinding) {
                                ForEach(UsageBarStyle.allCases) { style in
                                    Text(style.title).tag(style)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }
                } else {
                    settingsInsetPanel(
                        title: "Usage Indicators",
                        description: "Pi does not expose Codex-style rate-limit usage in v1."
                    ) {
                        settingsInfoRow(symbol: "info.circle", text: "Usage bars are only shown for agents that expose usage data.")
                    }
                }
            }
        }
    }

    var troubleshootingPage: some View {
        SettingsPanelCard {
            VStack(alignment: .leading, spacing: 10) {
                settingsSectionIntro(
                    title: "Troubleshooting",
                    description: "Diagnostics and refresh controls."
                )

                if let hint = viewModel.cliResolutionHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Run a refresh to capture command resolution details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.supportsUsage {
                    settingsFormRow("Cache TTL", detail: "Controls how often usage limits refresh automatically.") {
                        Stepper(value: limitsCacheTTLMinutesBinding, in: 1...120) {
                            Text("\(viewModel.limitsCacheTTLMinutes) min")
                                .font(.caption.weight(.semibold))
                        }
                    }
                }

                HStack(spacing: 8) {
                    ActionPillButton(title: "Open Config Directory", symbol: "folder.fill") {
                        viewModel.openMulticodexConfigDirectory()
                    }

                    ActionPillButton(title: viewModel.supportsUsage ? "Refresh Live" : "Refresh", symbol: viewModel.supportsUsage ? "bolt.horizontal.fill" : "arrow.clockwise", role: .primary) {
                        viewModel.supportsUsage ? viewModel.refreshLive() : viewModel.refresh()
                    }
                }
            }
        }
    }

    var advancedPage: some View {
        SettingsPanelCard {
            VStack(alignment: .leading, spacing: 10) {
                settingsSectionIntro(
                    title: "Diagnostics",
                    description: "Low-level runtime checks and maintenance tools."
                )

                settingsInfoRow(symbol: runtimeStatus.symbol, text: runtimeStatus.text, color: runtimeStatus.color)

                if let hint = viewModel.cliResolutionHint {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Run a refresh to capture command resolution details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    ActionPillButton(title: "Open Runtime", symbol: "terminal") {
                        viewModel.selectSettingsSection(.runtime)
                    }

                    ActionPillButton(title: "Refresh Live", symbol: "bolt.horizontal.fill", role: .primary) {
                        viewModel.refreshLive()
                    }

                    ActionPillButton(title: "Open Config Directory", symbol: "folder.fill") {
                        viewModel.openMulticodexConfigDirectory()
                    }
                }
            }
        }
    }

    var hiddenAdvancedPage: some View {
        SettingsPanelCard {
            VStack(alignment: .leading, spacing: 10) {
                settingsSectionIntro(
                    title: "Advanced",
                    description: "Currently hidden."
                )

                ActionPillButton(title: "Show Advanced", symbol: "gearshape.2", role: .primary) {
                    viewModel.setAdvancedSettingsVisible(true)
                    viewModel.selectSettingsSection(.advanced)
                }
            }
        }
    }

    var removalConfirmationSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let request = viewModel.pendingAccountRemovalRequest {
                Text(request.deleteData ? "Remove \(viewModel.currentAccountNounSingular) and delete data" : "Remove \(viewModel.currentAccountNounSingular)")
                    .font(.headline)

                Text(
                    request.deleteData
                        ? "This permanently removes \(request.accountName) and deletes its stored local data."
                        : "This removes \(request.accountName) from MultiCodex but leaves its data intact."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                if request.deleteData {
                    Text("Type \"\(request.accountName)\" to confirm.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    TextField("\(viewModel.currentAccountNounSingular.capitalized) name", text: $deleteConfirmationName)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        deleteConfirmationName = ""
                        viewModel.cancelPendingAccountRemoval()
                    }

                    Button(request.deleteData ? "Delete Data" : "Remove", role: .destructive) {
                        viewModel.executePendingAccountRemoval(confirming: deleteConfirmationName)
                        if viewModel.pendingAccountRemovalRequest == nil {
                            deleteConfirmationName = ""
                        }
                    }
                    .disabled(!canConfirmRemoval(request))
                }
            }
        }
        .padding(16)
        .frame(width: 390)
    }

    func canConfirmRemoval(_ request: PendingAccountRemovalRequest) -> Bool {
        if isAccountActionRunning {
            return false
        }
        if request.deleteData {
            return deleteConfirmationName.trimmingCharacters(in: .whitespacesAndNewlines) == request.accountName
        }
        return true
    }

    func feedbackRow(_ text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()

            Button("Dismiss") {
                viewModel.clearAccountActionFeedback()
            }
            .buttonStyle(.plain)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
