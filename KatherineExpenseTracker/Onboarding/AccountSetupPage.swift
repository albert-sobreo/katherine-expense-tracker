import SwiftUI
import SwiftData

/// Add accounts and people. Used as onboarding step 2 and as the Accounts screen.
struct AccountSetupPage: View {
    var isOnboarding = false
    var onDone: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @State private var formOwner: OwnerChoice?
    @State private var showPersonSheet = false

    /// Wraps the owner so the form sheet can be shown for a specific person or for "pick one".
    struct OwnerChoice: Identifiable {
        let id = UUID()
        let person: Person?
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
                    .padding(.top, isOnboarding ? 24 : 8)

                    AccountsByOwner { person in formOwner = OwnerChoice(person: person) }

                    Button { showPersonSheet = true } label: {
                        Label("Add a person", systemImage: "person.badge.plus")
                            .font(.outfit(13, .semibold)).tracking(1.6).textCase(.uppercase)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(p.chip, in: .rect(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
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
        .sheet(item: $formOwner) { choice in AccountForm(owner: choice.person) }
        .sheet(isPresented: $showPersonSheet) { PersonSheet() }
    }
}

#Preview {
    AccountSetupPage(isOnboarding: true, onDone: {})
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
