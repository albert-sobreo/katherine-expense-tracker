import SwiftUI
import SwiftData

/// One owner's accounts inside a rail. Mine comes first, then other people, then accounts with no owner.
/// Payees, when the rail shows them, come first as their own group.
struct RailGroup: Identifiable {
    let id: String
    let label: String
    let accounts: [Account]

    /// Groups every account by owner, most-used first inside each group.
    /// `withPayees` adds a Payees group in front (for Paid to and Received from).
    static func build(people: [Person], accounts all: [Account], withPayees: Bool = false) -> [RailGroup] {
        let accounts = all.filter { !$0.isPayee }
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
        if withPayees {
            let payees = all.filter(\.isPayee)
            if !payees.isEmpty { groups.insert(RailGroup(id: "payees", label: "Payees", accounts: sorted(payees)), at: 0) }
        }
        return groups
    }

    /// The owner of the first tile that is mostly visible at the left edge of a tile row. When the row is
    /// scrolled all the way to the end, the last group, so a short last group still gets its name.
    /// Assumes 13pt leading padding, 88pt tiles and 15pt dividers.
    static func owner(in groups: [RailGroup], scroll: RailScroll) -> RailGroup? {
        guard let last = groups.last else { return nil }
        let lead: CGFloat = 13, tile: CGFloat = 88, divider: CGFloat = 15
        let scrollable = scroll.content > scroll.width + 1
        if scrollable, scroll.x > 0, scroll.x >= scroll.content - scroll.width - 1 { return last }
        let probe = scroll.x + tile * 0.6
        var start = lead
        var current = groups[0]
        for (i, g) in groups.enumerated() {
            if i > 0 { start += divider }
            if start <= probe { current = g } else { break }
            start += CGFloat(g.accounts.count) * tile
        }
        return current
    }
}

/// Horizontal scroll position of a tile row, for working out which owner is in view.
struct RailScroll: Equatable {
    var x: CGFloat = 0
    var width: CGFloat = 0
    var content: CGFloat = 0
}

extension View {
    /// Keeps `scroll` in sync with this horizontal ScrollView's position.
    func trackRailScroll(_ scroll: Binding<RailScroll>) -> some View {
        onScrollGeometryChange(for: RailScroll.self) { geo in
            RailScroll(x: geo.contentOffset.x + geo.contentInsets.leading,
                       width: geo.containerSize.width,
                       content: geo.contentSize.width)
        } action: { _, new in
            scroll.wrappedValue = new
        }
    }
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

    private var visibleOwner: String { RailGroup.owner(in: groups, scroll: scroll)?.label ?? "" }

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
                            .accessibilityLabel(["Mine", "Others", "Payees"].contains(g.label) ? a.name : "\(g.label)'s \(a.name)")
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(p.muted)
                            .frame(width: tile, height: 80)
                            .background(p.chip, in: .rect(cornerRadius: 22))
                            .scaleEffect(0.95)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New account")
                }
                .padding(.horizontal, lead)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            // The selected tile's glow spills past the row; the row spans the full screen width,
            // so turning clipping off only lets the glow show, not stray tiles.
            .scrollClipDisabled()
            .padding(.horizontal, -16)
            .padding(.vertical, -12)
            .trackRailScroll($scroll)
            .sensoryFeedback(.selection, trigger: selection)
        }
    }
}
