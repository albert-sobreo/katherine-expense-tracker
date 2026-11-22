import SwiftUI
import SwiftData

/// Add accounts. Used as onboarding step 2 and as the Accounts screen.
/// People are added from the account form ("+ Person"); CSV and budget live in Settings.
struct AccountSetupPage: View {
    var isOnboarding = false
    var onDone: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @State private var formOwner: OwnerChoice?
    @State private var viewing: Account?
    @State private var editingPerson: Person?

    /// Wraps the owner so the form sheet can be shown for a specific person or for "pick one".
    struct OwnerChoice: Identifiable {
        let id = UUID()
        let person: Person?
        var payee = false
        var loan = false
    }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isOnboarding ? "Add your accounts" : "Accounts")
                            .font(.outfit(30, .bold))
                        Text("Tap + to add one. For an account you manage for someone else, like Mama's, pick + Person in the form.")
                            .font(.outfit(15))
                            .foregroundStyle(p.muted)
                    }
                    .padding(.top, isOnboarding ? 24 : 36)

                    AccountsByOwner(
                        onAdd: { person in formOwner = OwnerChoice(person: person) },
                        onAddPayee: { formOwner = OwnerChoice(person: nil, payee: true) },
                        onAddLoan: { formOwner = OwnerChoice(person: nil, loan: true) },
                        onEdit: { viewing = $0 },
                        onEditPerson: { editingPerson = $0 }
                    )
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
        .sheet(item: $formOwner) { choice in AccountForm(owner: choice.person, payee: choice.payee, loan: choice.loan) }
        #if os(iOS)
        .fullScreenCover(item: $viewing) { account in EntriesView(account: account) }
        #else
        .sheet(item: $viewing) { account in EntriesView(account: account).frame(minWidth: 420, minHeight: 760) }
        #endif
        .sheet(item: $editingPerson) { person in PersonEditSheet(person: person) }
    }
}

#Preview {
    AccountSetupPage(isOnboarding: true, onDone: {})
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
