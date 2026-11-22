import SwiftUI
import SwiftData

/// One owner's accounts inside a rail. Mine comes first, then other people, then accounts with no owner.
struct RailGroup: Identifiable {
    let id: String
    let label: String
    let accounts: [Account]

    /// Groups every account by owner, most-used first inside each group.
    static func build(people: [Person], accounts: [Account]) -> [RailGroup] {
        func usage(_ a: Account) -> Int { (a.outgoing?.count ?? 0) + (a.incoming?.count ?? 0) }
        func sorted(_ list: [Account]) -> [Account] {
            list.sorted { usage($0) != usage($1) ? usage($0) > usage($1) : $0.sortOrder < $1.sortOrder }
        }
        let owners = people.sorted { ($0.isMe ? 0 : 1, $0.sortOrder) < ($1.isMe ? 0 : 1, $1.sortOrder) }
        var groups: [RailGroup] = owners.compactMap { person in
            let mine = accounts.filter { $0.owner?.persistentModelID == person.persistentModelID }
            guard !mine.isEmpty else { return nil }
            return RailGroup(id: "\(person.persistentModelID.hashValue)",
                             label: person.isMe ? "Mine" : person.name,
                             accounts: sorted(mine))
        }
        let loose = accounts.filter { $0.owner == nil }
        if !loose.isEmpty { groups.append(RailGroup(id: "others", label: "Others", accounts: sorted(loose))) }
        return groups
    }
}

private struct RailScroll: Equatable {
    var x: CGFloat = 0
    var width: CGFloat = 0
    var content: CGFloat = 0
}

/// "Pay from" / "Paid to" row: label, owner name that follows the scroll, selected account on the right,
/// then a horizontal scroll of every account with thin dividers between owners and a "+" tile at the end.
struct AccountRail: View {
    let label: String
    let groups: [RailGroup]
    @Binding var selection: PersistentIdentifier?
    var onAdd: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var scroll = RailScroll()

    private let lead: CGFloat = 13
    private let tile: CGFloat = 88
    private let divider: CGFloat = 15

    private var selected: Account? {
        groups.lazy.flatMap(\.accounts).first { $0.persistentModelID == selection }
    }

    /// The owner whose tiles sit about a third of the way into the visible row.
    private var visibleOwner: String {
        guard let last = groups.last else { return "" }
        if scroll.content > 0, scroll.x >= scroll.content - scroll.width - 1, scroll.x > 0 { return last.label }
        let probe = scroll.x + scroll.width * 0.35
        var start = lead
        var current = groups[0].label
        for (i, g) in groups.enumerated() {
            if i > 0 { start += divider }
            if start <= probe { current = g.label } else { break }
            start += CGFloat(g.accounts.count) * tile
        }
        return current
    }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SectionLabel(label)
                if !groups.isEmpty {
                    Text(visibleOwner.uppercased())
                        .font(.outfit(11, .semibold))
                        .tracking(1.8)
                        .foregroundStyle(p.fg)
                        .contentTransition(.opacity)
                        .animation(.easeOut(duration: 0.15), value: visibleOwner)
                }
                Spacer()
                if let a = selected {
                    HStack(spacing: 4) {
                        Text(a.name).font(.outfit(12, .medium))
                        if !a.last4.isEmpty {
                            Text("•• \(a.last4)").font(.barlow(13, .medium))
                        }
                    }
                    .foregroundStyle(p.muted)
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { i, g in
                        if i > 0 {
                            Rectangle()
                                .fill(p.line)
                                .frame(width: 1, height: 56)
                                .padding(.horizontal, 7)
                        }
                        ForEach(g.accounts) { a in
                            let on = a.persistentModelID == selection
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    selection = on ? nil : a.persistentModelID
                                }
                            } label: {
                                AccountTile(name: a.name, last4: a.last4, colorHex: a.colorHex, selected: on)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(g.label == "Mine" || g.label == "Others" ? a.name : "\(g.label)'s \(a.name)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(p.muted)
                            .frame(width: 64, height: 80)
                            .background(p.chip, in: .rect(cornerRadius: 22))
                            .scaleEffect(0.94)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                    .accessibilityLabel("New account")
                }
                .padding(.horizontal, lead)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            .padding(.vertical, -12)
            .onScrollGeometryChange(for: RailScroll.self) { geo in
                RailScroll(x: geo.contentOffset.x + geo.contentInsets.leading,
                           width: geo.containerSize.width,
                           content: geo.contentSize.width)
            } action: { _, new in
                scroll = new
            }
        }
    }
}
