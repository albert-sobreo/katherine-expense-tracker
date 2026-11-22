import SwiftUI
import SwiftData

/// Every account as tiles, grouped by owner (MINE first), each group ending in a "+" tile.
struct AccountsByOwner: View {
    var onAdd: (Person?) -> Void

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
                    }
                    .padding(.horizontal, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(88), spacing: 0), count: 4), spacing: 0) {
                        ForEach(list) { account in
                            AccountTile(name: account.name, last4: account.last4, colorHex: account.colorHex)
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
        }
        .foregroundStyle(p.fg)
    }
}
