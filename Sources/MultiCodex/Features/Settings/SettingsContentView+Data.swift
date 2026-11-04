import SwiftUI

extension SettingsContentView {
    struct DataPane: View {
        @ObservedObject var viewModel: AccountsMenuViewModel
        @State private var isExporting = false
        @State private var isExportingAuthFiles = false
        @State private var isImporting = false
        @State private var importResult: AccountExportService.ImportResult?
        @State private var exportError: String?
        @State private var authFilesExportStatus: String?
        @State private var backupStatus: String?
        @State private var backupError: String?
        @State private var importError: String?

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelCard {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionIntro(
                            title: "Backup & Restore",
                            description: "Save all accounts and preferences to one JSON file. Import it on any Mac to restore them.",
                            symbol: "externaldrive.fill"
                        )

                        HStack(spacing: 8) {
                            ActionPillButton(
                                title: "Export Backup",
                                symbol: "square.and.arrow.up",
                                role: .primary,
                                isDisabled: isExporting
                            ) {
                                performExport()
                            }

                            ActionPillButton(
                                title: "Import Backup",
                                symbol: "square.and.arrow.down",
                                role: .secondary
                            ) {
                                isImporting = true
                            }
                            .fileImporter(
                                isPresented: $isImporting,
                                allowedContentTypes: [.json],
                                allowsMultipleSelection: false
                            ) { result in
                                performImport(result: result)
                            }

                            Spacer(minLength: 0)
                        }

                        if let status = backupStatus {
                            statusRow(status, color: DashboardTokens.statusGreen)
                        }
                        if let error = backupError {
                            statusRow("Export failed: \(error)", color: DashboardTokens.statusRed)
                        }
                        if let result = importResult {
                            statusRow(
                                "Import complete: \(result.imported) imported, \(result.skipped) skipped." +
                                    (result.conflicts.isEmpty ? "" : " Already present: \(result.conflicts.joined(separator: ", ")).")
                                , color: DashboardTokens.statusGreen
                            )
                        }
                        if let error = importError {
                            statusRow("Import failed: \(error)", color: DashboardTokens.statusRed)
                        }
                    }
                }

                SettingsPanelCard {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionIntro(
                            title: "Auth Files",
                            description: "Write one auth.json per account into a folder you choose. Use this to move a single account to another tool.",
                            symbol: "folder.fill"
                        )

                        HStack(spacing: 8) {
                            ActionPillButton(
                                title: "Export Auth Files",
                                symbol: "folder.badge.plus",
                                role: .secondary,
                                isDisabled: isExportingAuthFiles
                            ) {
                                performAuthFilesExport()
                            }
                            Spacer(minLength: 0)
                        }

                        if let status = authFilesExportStatus {
                            statusRow(status, color: DashboardTokens.statusGreen)
                        }
                        if let error = exportError {
                            statusRow("Export failed: \(error)", color: DashboardTokens.statusRed)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(DashboardTokens.Font.metadata())
                        .foregroundStyle(DashboardTokens.statusOrange)
                    Text("Exported files contain login tokens. Anyone with the file can use these accounts. Store it like a password.")
                        .font(DashboardTokens.Font.metadata())
                        .foregroundStyle(DashboardTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DashboardTokens.Spacing.cardRadius, style: .continuous)
                        .fill(DashboardTokens.statusOrange.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DashboardTokens.Spacing.cardRadius, style: .continuous)
                        .stroke(DashboardTokens.statusOrange.opacity(0.22), lineWidth: 0.5)
                )
            }
        }

        private func sectionIntro(title: String, description: String, symbol: String) -> some View {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbol)
                    .font(DashboardTokens.Font.cardHeading())
                    .foregroundStyle(DashboardTokens.accent)
                    .frame(width: 16)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(DashboardTokens.Font.cardHeading())
                        .foregroundStyle(DashboardTokens.textPrimary)
                    Text(description)
                        .font(DashboardTokens.Font.metadata())
                        .foregroundStyle(DashboardTokens.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        private func statusRow(_ text: String, color: Color) -> some View {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .padding(.top, 4)
                Text(text)
                    .font(DashboardTokens.Font.metadata())
                    .foregroundStyle(DashboardTokens.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }

        private func performExport() {
            isExporting = true
            backupError = nil
            backupStatus = nil
            importResult = nil

            guard let service = viewModel.accountService as? CodexAccountService else {
                backupError = "Service unavailable"
                isExporting = false
                return
            }

            do {
                let export = try AccountExportService.exportData(
                    accountService: service,
                    preferencesStore: viewModel.preferences
                )

                let panel = NSSavePanel()
                panel.allowedContentTypes = [.json]
                panel.nameFieldStringValue = "multicodex-backup.json"
                panel.begin { response in
                    if response == .OK, let url = panel.url {
                        do {
                            try AccountExportService.writeBackupData(export.data, to: url)
                            backupStatus = "Backup saved to \(url.lastPathComponent)."
                            if !export.skippedAccounts.isEmpty {
                                backupStatus! += " Skipped accounts with no login: " +
                                    export.skippedAccounts.joined(separator: ", ")
                            }
                        } catch {
                            backupError = error.localizedDescription
                        }
                    }
                    isExporting = false
                }
            } catch {
                backupError = error.localizedDescription
                isExporting = false
            }
        }

        private func performAuthFilesExport() {
            isExportingAuthFiles = true
            exportError = nil
            authFilesExportStatus = nil
            importResult = nil

            guard let service = viewModel.accountService as? CodexAccountService else {
                exportError = "Service unavailable"
                isExportingAuthFiles = false
                return
            }

            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Export"
            panel.message = "Choose a folder for per-account auth.json files."
            panel.begin { response in
                defer { isExportingAuthFiles = false }
                guard response == .OK, let url = panel.url else { return }

                do {
                    let result = try AccountExportService.exportAuthFiles(to: url, accountService: service)
                    if result.skippedAccounts.isEmpty {
                        authFilesExportStatus = "Exported \(result.exported) auth files."
                    } else {
                        authFilesExportStatus = "Exported \(result.exported) auth files. " +
                            "Skipped missing auth: \(result.skippedAccounts.joined(separator: ", "))"
                    }
                } catch {
                    exportError = error.localizedDescription
                }
            }
        }

        private func performImport(result: Result<[URL], Error>) {
            importError = nil
            importResult = nil
            backupStatus = nil
            backupError = nil

            guard let service = viewModel.accountService as? CodexAccountService else {
                importError = "Service unavailable"
                return
            }

            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    var prefs = viewModel.preferences
                    let importResult = try AccountExportService.importAccounts(
                        from: url,
                        accountService: service,
                        preferencesStore: &prefs
                    )
                    viewModel.preferences = prefs
                    viewModel.reloadPreferencesFromStore()
                    self.importResult = importResult
                    viewModel.refreshLive()
                } catch {
                    importError = error.localizedDescription
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
    }
}
