import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The things Kath rarely touches: monthly budget, people, and CSV import/export.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @Query(sort: \Entry.date) private var entries: [Entry]
    @AppStorage(Budget.key) private var budget = 0

    @State private var showBudget = false
    @State private var editingPerson: Person?
    @State private var showImporter = false
    @State private var exportDoc: CSVDocument?
    @State private var showExporter = false
    @State private var importMessage: String?

    private var others: [Person] { people.filter { !$0.isMe } }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            header(p)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    group("Budget", p) {
                        row("Monthly budget", "target",
                            sub: budget > 0 ? Money.peso(budget) + " a month" : "Not set", p) { showBudget = true }
                    }

                    group("People", p) {
                        if others.isEmpty {
                            Text("Add someone from the account form with + Person, like Mama when you add her BDO.")
                                .font(.outfit(13)).foregroundStyle(p.muted)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(Array(others.enumerated()), id: \.element.id) { i, person in
                            if i > 0 { divider(p) }
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
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .sheet(isPresented: $showBudget) { BudgetSheet() }
        .sheet(item: $editingPerson) { PersonEditSheet(person: $0) }
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
