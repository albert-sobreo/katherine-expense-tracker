import SwiftUI
import SwiftData

/// Shown when New entry is tapped before there's anything to log against.
/// Tells Kath what's missing and lets her add it right here.
struct NeedsSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.modelContext) private var context
    @Query private var accounts: [Account]
    @State private var formOwner: AccountSetupPage.OwnerChoice?

    private var readiness: Setup.Readiness { Setup.Readiness(accounts: accounts) }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(readiness.isReady ? "All set" : "Add an account first")
                    .font(.outfit(24, .bold))
                Text(readiness.isReady
                     ? "You can log your first entry now."
                     : "Add one of your own accounts, like GCash or Cash, so entries have somewhere to come from.")
                    .font(.outfit(15))
                    .foregroundStyle(p.muted)
            }

            VStack(spacing: 0) {
                requirement(p, done: readiness.hasMyAccount,
                            title: "One of your accounts",
                            detail: "Where money comes from or goes into, like GCash or Cash.",
                            action: "Add") { formOwner = .init(person: Setup.me(in: context)) }
            }
            .background(p.card, in: .rect(cornerRadius: 18))

            PrimaryButton(title: readiness.isReady ? "Continue" : "Not now") { dismiss() }
        }
        .foregroundStyle(p.fg)
        .padding(.horizontal, 16)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .background(p.bg)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .sheet(item: $formOwner) { choice in AccountForm(owner: choice.person) }
    }

    private func requirement(_ p: Palette, done: Bool, title: String, detail: String,
                             action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 24))
                .foregroundStyle(done ? p.fg : p.line)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.outfit(15, .semibold))
                Text(detail).font(.outfit(13)).foregroundStyle(p.muted)
            }
            Spacer(minLength: 8)
            if !done {
                Button(action, action: perform)
                    .buttonStyle(.plain)
                    .font(.outfit(13, .semibold))
                    .foregroundStyle(p.bg)
                    .padding(.horizontal, 14).frame(height: 32)
                    .background(p.fg, in: .capsule)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : "Missing")
    }
}
