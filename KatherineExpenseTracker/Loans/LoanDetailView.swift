import SwiftUI
import SwiftData

/// One person's loans: what they owe Kath (or she owes them) and every loan transfer behind it,
/// including any on a loan tile with their name. Tap a row to edit it.
struct LoanDetailView: View {
    let ref: LoanLine.Ref

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Entry.date, order: .reverse) private var allEntries: [Entry]
    @State private var editing: Entry?
    @State private var editingTile: Account?

    private var tile: Account? { ref.tile.flatMap { $0.isDeleted ? nil : $0 } }

    private var rows: [Entry] {
        let pid = ref.person?.persistentModelID
        let tid = tile?.persistentModelID
        return allEntries.filter { e in
            if let pid, e.loanPerson?.persistentModelID == pid { return true }
            if let tid, e.from?.persistentModelID == tid || e.to?.persistentModelID == tid { return true }
            return false
        }
    }

    /// What a row adds to what they owe Kath.
    private func effect(_ e: Entry) -> Int {
        if e.loanPerson != nil { return e.loanEffect }
        if let tid = tile?.persistentModelID {
            if e.to?.persistentModelID == tid { return e.amountCentavos }
            if e.from?.persistentModelID == tid { return -e.amountCentavos }
        }
        return 0
    }

    private var balance: Int { (tile?.openingCentavos ?? 0) + rows.reduce(0) { $0 + effect($1) } }

    var body: some View {
        let p = Palette.of(scheme)
        let green = Color(hex: scheme == .dark ? "#34D399" : "#059669")
        let rose = Color(hex: scheme == .dark ? "#FB7185" : "#E11D48")
        let b = balance
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(p.chip, in: .circle)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close")
                Spacer()
                Text(ref.name).font(.outfit(17, .bold)).lineLimit(1)
                Spacer()
                if let tile {
                    Button { editingTile = tile } label: {
                        Text("Edit")
                            .font(.outfit(13, .semibold))
                            .padding(.horizontal, 12).frame(height: 30)
                            .background(p.chip, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit loan")
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(spacing: 2) {
                        Text((b > 0 ? "\(ref.name) owes you" : (b < 0 ? "You owe \(ref.name)" : "Even")).uppercased())
                            .font(.outfit(11, .semibold)).tracking(1.8)
                            .foregroundStyle(p.muted)
                        Text(Money.peso(abs(b)))
                            .font(.barlow(54))
                            .monospacedDigit()
                            .foregroundStyle(b > 0 ? green : (b < 0 ? rose : p.fg))
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(p.card, in: .rect(cornerRadius: 22))

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Loan transfers").padding(.horizontal, 4)
                        VStack(spacing: 0) {
                            if let t = tile, t.openingCentavos != 0 {
                                line(title: "Starting amount", sub: "When the loan was added", amount: t.openingCentavos,
                                     green: green, rose: rose, p: p)
                                if !rows.isEmpty { Rectangle().fill(p.chip).frame(height: 1) }
                            }
                            ForEach(Array(rows.enumerated()), id: \.element.persistentModelID) { i, e in
                                if i > 0 { Rectangle().fill(p.chip).frame(height: 1) }
                                Button { editing = e } label: {
                                    line(title: "\(EntriesView.describe(e.from)) to \(EntriesView.describe(e.to))",
                                         sub: e.date.formatted(.dateTime.month(.abbreviated).day().year())
                                            + (e.note.isEmpty ? "" : " · \(e.note)"),
                                         amount: effect(e), green: green, rose: rose, p: p)
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Edit")
                            }
                            if rows.isEmpty && (tile?.openingCentavos ?? 0) == 0 {
                                Text("No loan transfers yet.")
                                    .font(.outfit(14)).foregroundStyle(p.muted)
                                    .frame(maxWidth: .infinity, minHeight: 70)
                            }
                        }
                        .background(p.card, in: .rect(cornerRadius: 20))
                        Text("+ means \(ref.name) owes you more, − means less (or you owe them).")
                            .font(.outfit(12)).foregroundStyle(p.muted)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .presentationDragIndicator(.visible)
        .sheet(item: $editing) { EntryView(editing: $0) }
        .sheet(item: $editingTile) { AccountForm(editing: $0) }
    }

    private func line(title: String, sub: String, amount: Int, green: Color, rose: Color, p: Palette) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.outfit(14, .semibold)).lineLimit(1)
                Text(sub).font(.outfit(12)).foregroundStyle(p.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(Money.peso(amount, signed: true))
                .font(.barlow(19))
                .monospacedDigit()
                .foregroundStyle(amount > 0 ? green : (amount < 0 ? rose : p.fg))
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .contentShape(.rect)
    }
}
