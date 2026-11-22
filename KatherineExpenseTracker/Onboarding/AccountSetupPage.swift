import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Add accounts and people. Used as onboarding step 2 and as the Accounts screen.
struct AccountSetupPage: View {
    var isOnboarding = false
    var onDone: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @State private var formOwner: OwnerChoice?
    @State private var showPersonSheet = false
    @State private var viewing: Account?
    @State private var editingPerson: Person?
    @State private var showImporter = false
    @State private var exportDoc: CSVDocument?
    @State private var showExporter = false
    @State private var importMessage: String?
    @Query(sort: \Entry.date) private var entries: [Entry]

    /// Wraps the owner so the form sheet can be shown for a specific person or for "pick one".
    struct OwnerChoice: Identifiable {
        let id = UUID()
        let person: Person?
        var payee = false
    }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isOnboarding ? "Add your accounts" : "Accounts")
                            .font(.outfit(30, .bold))
                        Text("Start with the ones you use most, then anyone whose accounts you manage, like Mama. You can add more anytime.")
                            .font(.outfit(15))
                            .foregroundStyle(p.muted)
                    }
                    .padding(.top, isOnboarding ? 24 : 36)

                    AccountsByOwner(
                        onAdd: { person in formOwner = OwnerChoice(person: person) },
                        onAddPayee: { formOwner = OwnerChoice(person: nil, payee: true) },
                        onEdit: { viewing = $0 },
                        onEditPerson: { editingPerson = $0 }
                    )

                    Button { showPersonSheet = true } label: {
                        Label("Add a person", systemImage: "person.badge.plus")
                            .font(.outfit(13, .semibold)).tracking(1.6).textCase(.uppercase)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(p.chip, in: .rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)

                    if !isOnboarding { dataSection(p) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            if isOnboarding {
                VStack(spacing: 6) {
                    PrimaryButton(title: accounts.isEmpty ? "Skip for now" : "Continue", action: onDone)
                    if accounts.isEmpty {
                        Text("You'll be asked to add one of yours before your first entry.")
                            .font(.outfit(12))
                            .foregroundStyle(p.muted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .onAppear { Setup.me(in: context) }
        .sheet(item: $formOwner) { choice in AccountForm(owner: choice.person, payee: choice.payee) }
        .sheet(isPresented: $showPersonSheet) { PersonSheet() }
        .sheet(item: $viewing) { account in EntriesView(account: account) }
        .sheet(item: $editingPerson) { person in PersonEditSheet(person: person) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importMessage = "Couldn't open that file."
                return
            }
            let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            importMessage = CSV.importText(text, into: context).summary
        }
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .commaSeparatedText,
                      defaultFilename: "Budget \(Date.now.formatted(.iso8601.year().month().day()))") { _ in }
        .alert("Import", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
    }
}

extension AccountSetupPage {
    /// Import from CSV (e.g. Kath's Excel sheet saved as CSV) and export everything as a backup.
    fileprivate func dataSection(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Data").padding(.horizontal, 4)
            VStack(spacing: 0) {
                dataRow("Import from CSV", "square.and.arrow.down", sub: "Date, Type, Amount, From, To, Note", p) {
                    showImporter = true
                }
                Rectangle().fill(p.chip).frame(height: 1).padding(.leading, 48)
                dataRow("Export to CSV", "square.and.arrow.up", sub: "\(entries.count) \(entries.count == 1 ? "entry" : "entries"), opens in Excel", p) {
                    exportDoc = CSVDocument(text: CSV.export(entries))
                    showExporter = true
                }
            }
            .background(p.card, in: .rect(cornerRadius: 18))
        }
        .padding(.top, 8)
    }

    private func dataRow(_ title: String, _ icon: String, sub: String, _ p: Palette, action: @escaping () -> Void) -> some View {
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

#Preview {
    AccountSetupPage(isOnboarding: true, onDone: {})
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
