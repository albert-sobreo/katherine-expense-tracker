import SwiftUI
import SwiftData

/// Who owes Kath and who she owes: one row per loan, biggest first, with totals on top.
/// Tapping a row opens that loan's transactions.
struct LoansView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.inSplitDetail) private var inSplitDetail
    @Environment(\.openDetail) private var openDetail
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var viewing: Account?
    @State private var adding = false

    private var loans: [Account] { accounts.filter(\.isLoan) }
    private var owesYou: [Account] {
        loans.filter { $0.balanceCentavos > 0 }.sorted { $0.balanceCentavos > $1.balanceCentavos }
    }
    private var youOwe: [Account] {
        loans.filter { $0.balanceCentavos < 0 }.sorted { $0.balanceCentavos < $1.balanceCentavos }
    }
    private var even: [Account] { loans.filter { $0.balanceCentavos == 0 } }

    var body: some View {
        let p = Palette.of(scheme)
        let green = Color(hex: scheme == .dark ? "#34D399" : "#059669")
        let rose = Color(hex: scheme == .dark ? "#FB7185" : "#E11D48")
        let inTotal = owesYou.reduce(0) { $0 + $1.balanceCentavos }
        let outTotal = -youOwe.reduce(0) { $0 + $1.balanceCentavos }
        VStack(spacing: 0) {
            header(p)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 0) {
                        total("Owed to you", inTotal, green, p)
                        Rectangle().fill(p.line).frame(width: 1, height: 44)
                        total("You owe", outTotal, rose, p)
                    }
                    .padding(.vertical, 16)
                    .background(p.card, in: .rect(cornerRadius: 20))

                    if loans.isEmpty {
                        VStack(spacing: 8) {
                            Text("No loans yet").font(.outfit(17, .semibold))
                            Text("Add one for each person you lend to or borrow from. Then log lending and paybacks as Transfers to or from their tile.")
                                .font(.outfit(14)).foregroundStyle(p.muted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                    }
                    if !owesYou.isEmpty { section("Owes you", owesYou, green, p) }
                    if !youOwe.isEmpty { section("You owe", youOwe, rose, p) }
                    if !even.isEmpty { section("Even", even, p.muted, p) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .bottom) {
            Button { adding = true } label: {
                Label("New loan", systemImage: "plus")
                    .font(.outfit(13, .semibold)).tracking(2).textCase(.uppercase)
                    .foregroundStyle(p.bg)
                    .padding(.leading, 22).padding(.trailing, 26).frame(height: 56)
                    .background(p.fg, in: .capsule)
                    .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.25), radius: 14, y: 10)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 18)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .sheet(isPresented: $adding) { AccountForm(loan: true) }
        #if os(iOS)
        .sheet(item: $viewing) { EntriesView(account: $0) }
        #else
        .sheet(item: $viewing) { EntriesView(account: $0).frame(minWidth: 420, minHeight: 760) }
        #endif
    }

    private func header(_ p: Palette) -> some View {
        HStack {
            if inSplitDetail {
                Color.clear.frame(width: 36, height: 36)
            } else {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                        .background(p.chip, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            Spacer()
            Text("Loans").font(.outfit(17, .bold))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .frame(height: 40)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func total(_ label: String, _ value: Int, _ color: Color, _ p: Palette) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.outfit(10, .semibold)).tracking(1.6)
                .foregroundStyle(p.muted)
            Text(Money.peso(value))
                .font(.barlow(28))
                .monospacedDigit()
                .foregroundStyle(value == 0 ? p.fg : color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func section(_ title: String, _ list: [Account], _ color: Color, _ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title).padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, a in
                    if i > 0 { Rectangle().fill(scheme == .dark ? p.chip : p.bg).frame(height: 1) }
                    Button { if let openDetail { openDetail(.account(a.persistentModelID)) } else { viewing = a } } label: { row(a, color, p) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Show transactions")
                }
            }
            .background(p.card, in: .rect(cornerRadius: 20))
        }
    }

    private func row(_ a: Account, _ color: Color, _ p: Palette) -> some View {
        let last = ((a.outgoing ?? []) + (a.incoming ?? [])).map(\.date).max()
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: a.colorHex))
                .frame(width: 34, height: 34)
                .overlay(
                    Text(String(a.name.prefix(1)).uppercased())
                        .font(.outfit(15, .bold))
                        .foregroundStyle(Color.tileText(hex: a.colorHex))
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(a.name).font(.outfit(15, .semibold)).lineLimit(1)
                Text(last.map { "Last \($0.formatted(.dateTime.month(.abbreviated).day()))" } ?? "No entries yet")
                    .font(.outfit(12)).foregroundStyle(p.muted)
            }
            Spacer(minLength: 8)
            Text(Money.peso(abs(a.balanceCentavos)))
                .font(.barlow(20))
                .monospacedDigit()
                .foregroundStyle(color)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(p.muted)
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
        .contentShape(.rect)
    }
}
