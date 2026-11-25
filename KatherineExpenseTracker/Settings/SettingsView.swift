import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The things rarely touched: accounts, Home accounts, budget, people, CSV, and backup and restore.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @Query(sort: \Entry.date) private var entries: [Entry]
    @AppStorage(Budget.key) private var budget = 0

    @State private var showBudget = false
    @State private var showAccounts = false
    @State private var addingPerson = false
    @State private var showHomeAccounts = false
    @Query private var allAccounts: [Account]
    @State private var editingPerson: Person?
    @State private var showImporter = false
    @State private var exportDoc: CSVDocument?
    @State private var showExporter = false
    @State private var importMessage: String?
    @State private var alertTitle = "Import"
    @State private var backupDoc: BackupDocument?
    @State private var showBackupExporter = false
    @State private var showBackupImporter = false
    /// A backup read from a file, waiting for the user to confirm replacing everything.
    @State private var pendingRestore: Backup?

    private var others: [Person] { people.filter { !$0.isMe } }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            header(p)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    group("Accounts", p) {
                        row("Accounts", "creditcard", sub: "Add, edit or delete accounts, payees and loans", p) {
                            showAccounts = true
                        }
                    }

                    group("Home", p) {
                        let banks = allAccounts.filter { !$0.isPayee && !$0.isLoan }
                        let shown = banks.filter(\.showOnHome).count
                        row("Accounts on Home", "house", sub: shown == banks.count ? "All accounts" : "\(shown) of \(banks.count) accounts", p) {
                            showHomeAccounts = true
                        }
                    }

                    group("Budget", p) {
                        row("Monthly budget", "target",
                            sub: budget > 0 ? Money.peso(budget) + " a month" : "Not set", p) { showBudget = true }
                    }

                    group("People", p) {
                        row("Add person", "person.badge.plus", sub: "Someone whose accounts you handle, like your brother", p) {
                            addingPerson = true
                        }
                        ForEach(others) { person in
                            divider(p)
                            let n = (person.accounts ?? []).count
                            row(person.name, "person", sub: n == 1 ? "1 account" : "\(n) accounts", p) {
                                editingPerson = person
                            }
                        }
                    }

                    group("Data", p) {
                        row("Import from CSV", "square.and.arrow.down", sub: "Date, Type, Amount, From, To, Note", p) {
                            showImporter = true
                        }
                        divider(p)
                        row("Export to CSV", "square.and.arrow.up",
                            sub: "\(entries.count) \(entries.count == 1 ? "entry" : "entries"), opens in Excel", p) {
                            exportDoc = CSVDocument(text: CSV.export(entries))
                            showExporter = true
                        }
                    }

                    group("Backup", p) {
                        row("Back up everything", "externaldrive", sub: "Accounts, people, balances, entries and budget in one file", p) {
                            if let data = try? Backup.make(context: context, budget: budget).encoded() {
                                backupDoc = BackupDocument(data: data)
                                showBackupExporter = true
                            }
                        }
                        divider(p)
                        row("Restore from backup", "arrow.counterclockwise", sub: "Replaces everything in the app with the file", p) {
                            showBackupImporter = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            // Backup's file sheets live here: one view can only carry one importer and one exporter.
            .fileExporter(isPresented: $showBackupExporter, document: backupDoc, contentType: .json,
                          defaultFilename: "Katherine backup \(Date.now.formatted(.iso8601.year().month().day()))") { result in
                if case .success = result {
                    alertTitle = "Backup saved"
                    importMessage = "Keep the file somewhere safe, like iCloud Drive. Restore from backup brings everything back."
                }
            }
            .fileImporter(isPresented: $showBackupImporter, allowedContentTypes: [.json]) { result in
                guard case .success(let url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url), let backup = try? Backup.decode(data) else {
                    alertTitle = "Restore"
                    importMessage = "That file isn't a backup from this app."
                    return
                }
                pendingRestore = backup
            }
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .confirmationDialog("Replace everything with this backup?",
                            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                            titleVisibility: .visible) {
            Button("Replace everything", role: .destructive) {
                guard let backup = pendingRestore else { return }
                backup.restore(into: context)
                budget = backup.budget
                pendingRestore = nil
                alertTitle = "Restored"
                importMessage = "Everything is back as of the backup: \(backup.summary)."
            }
        } message: {
            Text("Backup: \(pendingRestore?.summary ?? ""). Everything in the app now is deleted first, on all devices using this iCloud account. Back up first if you might need it.")
        }
        .sheet(isPresented: $showBudget) { BudgetSheet() }
        .sheet(isPresented: $addingPerson) { PersonSheet() }
        .sheet(isPresented: $showHomeAccounts) { HomeAccountsSheet() }
        .sheet(isPresented: $showAccounts) {
            AccountSetupPage(onDone: { showAccounts = false })
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingPerson) { PersonEditSheet(person: $0) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                alertTitle = "Import"
                importMessage = "Couldn't open that file."
                return
            }
            let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            alertTitle = "Import"
            importMessage = CSV.importText(text, into: context).summary
        }
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .commaSeparatedText,
                      defaultFilename: "Budget \(Date.now.formatted(.iso8601.year().month().day()))") { _ in }
        .alert(alertTitle, isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
    }

    private func header(_ p: Palette) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(p.chip, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Spacer()
            Text("Settings").font(.outfit(17, .bold))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .frame(height: 40)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func group<Content: View>(_ title: String, _ p: Palette, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title).padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .background(p.card, in: .rect(cornerRadius: 18))
        }
    }

    private func divider(_ p: Palette) -> some View {
        Rectangle().fill(p.chip).frame(height: 1).padding(.leading, 48)
    }

    private func row(_ title: String, _ icon: String, sub: String, _ p: Palette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.outfit(15, .semibold))
                    Text(sub).font(.outfit(12)).foregroundStyle(p.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(p.muted)
            }
            .padding(.horizontal, 14)
            .frame(height: 60)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
