import SwiftUI
import SwiftData

/// Placeholder Home until the real one is built: shows accounts and the New entry button,
/// which checks that the accounts an entry needs exist first.
struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @State private var showSetup = false
    @State private var showAccounts = false
    @State private var showEntry = false

    var body: some View {
        let p = Palette.of(scheme)
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(Date.now.formatted(.dateTime.month(.wide)))
                            .font(.outfit(26, .bold))
                        Text(Date.now.formatted(.dateTime.year()))
                            .font(.barlow(22, .medium))
                            .foregroundStyle(p.muted)
                        Spacer()
                        Button { showAccounts = true } label: {
                            Image(systemName: "creditcard")
                                .font(.system(size: 17, weight: .medium))
                                .frame(width: 40, height: 40)
                                .background(p.chip, in: .circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Accounts")
                    }

                    if accounts.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No accounts yet").font(.outfit(17, .semibold))
                            Text("Add your accounts and the people you handle money for, then start logging.")
                                .font(.outfit(14)).foregroundStyle(p.muted)
                            Button("Add accounts") { showAccounts = true }
                                .buttonStyle(.plain)
                                .font(.outfit(13, .semibold))
                                .foregroundStyle(p.bg)
                                .padding(.horizontal, 16).frame(height: 36)
                                .background(p.fg, in: .capsule)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(p.card, in: .rect(cornerRadius: 22))
                    } else {
                        SectionLabel("Accounts")
                        ScrollView(.horizontal) {
                            HStack(spacing: 0) {
                                ForEach(accounts) { a in
                                    AccountTile(name: a.name, last4: a.last4, colorHex: a.colorHex)
                                }
                            }
                            .padding(.horizontal, 13)
                        }
                        .scrollIndicators(.hidden)
                        .padding(.horizontal, -16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 120)
            }

            Button(action: newEntry) {
                Label("New entry", systemImage: "plus")
                    .font(.outfit(13, .semibold)).tracking(2).textCase(.uppercase)
                    .foregroundStyle(p.bg)
                    .padding(.horizontal, 26).frame(height: 60)
                    .background(p.fg, in: .capsule)
                    .shadow(color: .black.opacity(0.25), radius: 14, y: 10)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 12)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .sheet(isPresented: $showSetup) { NeedsSetupSheet() }
        .sheet(isPresented: $showAccounts) {
            AccountSetupPage(onDone: { showAccounts = false })
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEntry) {
            Text("The entry screen is built next.")
                .font(.outfit(15))
                .presentationDetents([.height(200)])
        }
    }

    private func newEntry() {
        if Setup.Readiness(accounts: accounts).isReady {
            showEntry = true
        } else {
            showSetup = true
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
