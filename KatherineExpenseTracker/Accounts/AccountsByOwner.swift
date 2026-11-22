import SwiftUI
import SwiftData

/// Every account as tiles, grouped by owner (MINE first), each group ending in a "+" tile.
/// Payees (Meralco, Grab, salary) get their own section at the end.
struct AccountsByOwner: View {
    var onAdd: (Person?) -> Void
    var onAddPayee: () -> Void = {}
    /// Tapping a tile: opens the account's transactions.
    var onEdit: (Account) -> Void = { _ in }
    /// Tapping a group's "Edit": rename, reorder or delete that person.
    var onEditPerson: (Person) -> Void = { _ in }

    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    private struct OwnerGroup: Identifiable {
        let person: Person
        let accounts: [Account]
        var id: PersistentIdentifier { person.persistentModelID }
    }

    private var groups: [OwnerGroup] {
        people
            .sorted { ($0.isMe ? 0 : 1, $0.sortOrder) < ($1.isMe ? 0 : 1, $1.sortOrder) }
            .map { person in
                OwnerGroup(person: person,
                           accounts: accounts.filter { $0.owner?.persistentModelID == person.persistentModelID })
            }
    }

    private var payees: [Account] { accounts.filter(\.isPayee) }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(alignment: .leading, spacing: 22) {
            ForEach(groups) { group in
                let person = group.person
                let list = group.accounts
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(person.name.uppercased())
                            .font(.outfit(11, .semibold)).tracking(1.8)
                        Spacer()
                        Text(list.count == 1 ? "1 account" : "\(list.count) accounts")
                            .font(.outfit(12, .medium)).foregroundStyle(p.muted)
                        Button("Edit") { onEditPerson(person) }
                            .buttonStyle(.plain)
                            .font(.outfit(12, .semibold))
                            .padding(.horizontal, 10).frame(height: 24)
                            .background(p.chip, in: .capsule)
                            .padding(.leading, 6)
                            .accessibilityLabel(person.isMe ? "Edit my accounts" : "Edit \(person.name)")
                    }
                    .padding(.horizontal, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(88), spacing: 0), count: 4), spacing: 0) {
                        ForEach(list) { account in
                            Button { onEdit(account) } label: {
                                AccountTile(name: account.name, last4: account.last4, colorHex: account.colorHex)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Show transactions")
                        }
                        Button { onAdd(person) } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(p.muted)
                                .frame(width: 88, height: 80)
                                .overlay(RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(p.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                                .scaleEffect(0.95)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(person.isMe ? "Add one of my accounts" : "Add one of \(person.name)'s accounts")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("PAYEES")
                        .font(.outfit(11, .semibold)).tracking(1.8)
                    Spacer()
                    Text(payees.isEmpty ? "Bills, stores, salary" : (payees.count == 1 ? "1 payee" : "\(payees.count) payees"))
                        .font(.outfit(12, .medium)).foregroundStyle(p.muted)
                }
                .padding(.horizontal, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(88), spacing: 0), count: 4), spacing: 0) {
                    ForEach(payees) { payee in
                        Button { onEdit(payee) } label: {
                            AccountTile(name: payee.name, last4: "", colorHex: payee.colorHex)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Show transactions")
                    }
                    Button(action: onAddPayee) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(p.muted)
                            .frame(width: 88, height: 80)
                            .overlay(RoundedRectangle(cornerRadius: 22)
                                .strokeBorder(p.line, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                            .scaleEffect(0.95)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a payee")
                }
            }
        }
        .foregroundStyle(p.fg)
    }
}
