import SwiftUI
import SwiftData

/// Pick which accounts Home shows and counts: balances, Spent, Income, Net balance, the widget and Analytics.
/// All are on by default. Hidden ones still work everywhere else (entry rails, Accounts, the spreadsheet).
struct HomeAccountsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    private var groups: [RailGroup] { RailGroup.build(people: people, accounts: accounts) }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            HStack {
                Text("Accounts on Home").font(.outfit(20, .semibold))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(p.chip, in: .circle)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Checked accounts show on Home and count in Spent, Income, Net balance, the widget and Analytics. Unchecked ones still work everywhere else.")
                        .font(.outfit(14)).foregroundStyle(p.muted)
                    ForEach(groups) { g in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                SectionLabel(g.label)
                                Spacer()
                                let allOn = g.accounts.allSatisfy(\.showOnHome)
                                Button(allOn ? "Hide all" : "Show all") {
                                    for a in g.accounts { a.showOnHome = !allOn }
                                }
                                .buttonStyle(.plain)
                                .font(.outfit(13, .medium))
                            }
                            .padding(.horizontal, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(g.accounts.enumerated()), id: \.element.id) { i, a in
                                    if i > 0 { Rectangle().fill(p.chip).frame(height: 1).padding(.leading, 52) }
                                    row(a, p)
                                }
                            }
                            .background(p.card, in: .rect(cornerRadius: 18))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .presentationDragIndicator(.visible)
    }

    private func row(_ a: Account, _ p: Palette) -> some View {
        Button { a.showOnHome.toggle() } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(hex: a.colorHex))
                    .frame(width: 26, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(a.name).font(.outfit(15, .semibold)).lineLimit(1)
                    let sub = [a.kind == .credit ? "Credit" : nil, a.last4.isEmpty ? nil : "•• \(a.last4)"]
                        .compactMap { $0 }.joined(separator: " ")
                    if !sub.isEmpty { Text(sub).font(.barlow(14)).foregroundStyle(p.muted) }
                }
                Spacer()
                Image(systemName: a.showOnHome ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(a.showOnHome ? p.fg : p.muted)
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: a.showOnHome)
        .accessibilityAddTraits(a.showOnHome ? .isSelected : [])
    }
}
