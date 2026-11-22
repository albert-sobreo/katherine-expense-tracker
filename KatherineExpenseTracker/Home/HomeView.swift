import SwiftUI
import SwiftData

/// Home: month header, Spent this month with Income · Expense · Net balance, balances by owner,
/// recent entries by day, and the floating New entry button.
struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]

    @State private var month = HomeView.startOfMonth(.now)
    @State private var showSetup = false
    @State private var showAccounts = false
    @State private var showEntry = false
    @State private var balanceScroll = RailScroll()
    @State private var viewingAccount: Account?
    @State private var editingEntry: Entry?
    @State private var showSheet = false
    @State private var showMonthSheet = false
    @State private var showAnalytics = false

    private static func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    private var isThisMonth: Bool { Calendar.current.isDate(month, equalTo: .now, toGranularity: .month) }
    private var totals: MonthTotals { MonthTotals(entries: entries, month: month) }
    private var balanceGroups: [RailGroup] { RailGroup.build(people: people, accounts: accounts) }
    private var hasMyAccount: Bool { Setup.Readiness(accounts: accounts).isReady }

    var body: some View {
        let p = Palette.of(scheme)
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(p)
                    if hasMyAccount {
                        hero(p)
                    } else {
                        emptyCard(p)
                    }
                    if !balanceGroups.isEmpty { balances(p) }
                    if hasMyAccount { recent(p) }
                }
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)

            LinearGradient(colors: [p.bg.opacity(0), p.bg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.7))
                .frame(height: 130)
                .allowsHitTesting(false)

            Button(action: newEntry) {
                Label("New entry", systemImage: "plus")
                    .font(.outfit(13, .semibold)).tracking(2).textCase(.uppercase)
                    .foregroundStyle(p.bg)
                    .padding(.leading, 22).padding(.trailing, 26).frame(height: 60)
                    .background(p.fg, in: .capsule)
                    .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.28), radius: 14, y: 12)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 18)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .sheet(isPresented: $showSetup) { NeedsSetupSheet() }
        .sheet(isPresented: $showMonthSheet) {
            MonthPickerSheet(selection: Binding(get: { month }, set: { if let m = $0 { month = m } }),
                             entryDates: entries.map(\.date))
        }
        .sheet(isPresented: $showAccounts) {
            AccountSetupPage(onDone: { showAccounts = false })
                .presentationDragIndicator(.visible)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showEntry) { EntryView() }
        .fullScreenCover(item: $editingEntry) { entry in EntryView(editing: entry) }
        .fullScreenCover(isPresented: $showSheet) { EntriesView(month: month) }
        .fullScreenCover(isPresented: $showAnalytics) { AnalyticsView(month: month) }
        .fullScreenCover(item: $viewingAccount) { EntriesView(account: $0) }
        #else
        .sheet(item: $editingEntry) { entry in EntryView(editing: entry).frame(minWidth: 420, minHeight: 760) }
        .sheet(isPresented: $showSheet) { EntriesView(month: month).frame(minWidth: 420, minHeight: 760) }
        .sheet(isPresented: $showAnalytics) { AnalyticsView(month: month).frame(minWidth: 420, minHeight: 760) }
        .sheet(item: $viewingAccount) { EntriesView(account: $0).frame(minWidth: 420, minHeight: 760) }
        .sheet(isPresented: $showEntry) { EntryView().frame(minWidth: 420, minHeight: 760) }
        #endif
    }

    // MARK: Header

    private func header(_ p: Palette) -> some View {
        HStack {
            Button { showMonthSheet = true } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(month.formatted(.dateTime.month(.wide)))
                        .font(.outfit(26, .bold))
                        .foregroundStyle(p.fg)
                    Text(month.formatted(.dateTime.year()))
                        .font(.barlow(22, .medium))
                        .foregroundStyle(p.muted)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(p.muted)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Month, \(month.formatted(.dateTime.month(.wide).year()))")
            Spacer()
            Button { showSheet = true } label: {
                Image(systemName: "tablecells")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(p.chip, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Spreadsheet view")
            Button { showAnalytics = true } label: {
                Image(systemName: "chart.bar")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(p.chip, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Analytics")
            Button { showAccounts = true } label: {
                Image(systemName: "creditcard")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(p.chip, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Accounts")
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
    }

    // MARK: Totals

    private func hero(_ p: Palette) -> some View {
        let t = totals
        return VStack(spacing: 2) {
            Text(isThisMonth ? "SPENT THIS MONTH" : "SPENT IN \(month.formatted(.dateTime.month(.wide)).uppercased())")
                .font(.outfit(11, .semibold)).tracking(2)
                .foregroundStyle(p.muted)
            ZStack {
                Text("₱")
                    .font(.barlow(30, .medium))
                    .foregroundStyle(p.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                Text(Money.number(t.expense))
                    .font(.barlow(84))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 34)
            }
            .frame(height: 84)
            HStack(spacing: 0) {
                stat("Income", Money.peso(t.income), p)
                Rectangle().fill(p.line).frame(width: 1, height: 30)
                stat("Expense", Money.peso(t.expense), p)
                Rectangle().fill(p.line).frame(width: 1, height: 30)
                stat("Net balance", Money.peso(MonthTotals.netBalance(accounts)), p)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) { Rectangle().fill(p.line).frame(height: 1) }
            .padding(.top, 8)
        }
        .padding(.top, 4)
        .padding(.horizontal, 16)
    }

    private func stat(_ label: String, _ value: String, _ p: Palette) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.outfit(10, .semibold)).tracking(1.6)
                .foregroundStyle(p.muted)
            Text(value)
                .font(.barlow(22))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func emptyCard(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No accounts yet").font(.outfit(17, .semibold))
            Text("Add your accounts and the people you handle money for, then start logging.")
                .font(.outfit(14)).foregroundStyle(p.muted)
            Button("Add accounts") { showAccounts = true }
                .buttonStyle(.plain)
                .font(.outfit(13, .semibold))
                .foregroundStyle(p.bg)
                .padding(.horizontal, 16).frame(height: 36)
                .background(p.fg, in: .capsule)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.card, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 16)
    }

    // MARK: Balances

    private func balances(_ p: Palette) -> some View {
        let groups = balanceGroups
        let current = RailGroup.owner(in: groups, scroll: balanceScroll) ?? groups[0]
        let total = current.accounts.reduce(0) { $0 + $1.balanceCentavos }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Text("BALANCES").foregroundStyle(p.muted)
                    Text(current.label.uppercased())
                        .foregroundStyle(p.fg)
                        .contentTransition(.opacity)
                        .animation(.easeOut(duration: 0.15), value: current.label)
                }
                .font(.outfit(11, .semibold)).tracking(1.8)
                Spacer()
                Text(Money.peso(total))
                    .font(.barlow(16))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.2), value: total)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { i, g in
                        if i > 0 {
                            Rectangle().fill(p.line)
                                .frame(width: 1, height: 56)
                                .padding(.horizontal, 7)
                        }
                        ForEach(g.accounts) { a in
                            Button { viewingAccount = a } label: { BalanceTile(account: a) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Show transactions")
                        }
                    }
                }
                .padding(.horizontal, 13)
                .padding(.top, 4).padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .trackRailScroll($balanceScroll)
        }
    }

    // MARK: Recent

    private struct Day: Identifiable {
        let id: Date
        let entries: [Entry]
    }

    private var days: [Day] {
        let cal = Calendar.current
        let inMonth = entries.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }.prefix(25)
        var out: [Day] = []
        for e in inMonth {
            let d = cal.startOfDay(for: e.date)
            if out.last?.id == d {
                out[out.count - 1] = Day(id: d, entries: out[out.count - 1].entries + [e])
            } else {
                out.append(Day(id: d, entries: [e]))
            }
        }
        return out
    }

    private func recent(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Recent")
                Spacer()
                Button("See all") { showSheet = true }
                    .buttonStyle(.plain)
                    .font(.outfit(13, .medium))
            }
            .padding(.horizontal, 4)
            if days.isEmpty {
                Text(isThisMonth ? "Nothing logged this month yet." : "Nothing logged in \(month.formatted(.dateTime.month(.wide))).")
                    .font(.outfit(14))
                    .foregroundStyle(p.muted)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(p.card, in: .rect(cornerRadius: 18))
            }
            ForEach(days) { day in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(dayLabel(day.id))
                        Spacer()
                        Text(Money.peso(dayTotal(day.entries), signed: true)).font(.barlow(14))
                    }
                    .font(.outfit(12, .semibold))
                    .foregroundStyle(p.muted)
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(day.entries.enumerated()), id: \.element.persistentModelID) { i, e in
                            if i > 0 { Rectangle().fill(scheme == .dark ? p.chip : p.bg).frame(height: 1) }
                            Button { editingEntry = e } label: { row(e, p) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Edit")
                        }
                    }
                    .background(p.card, in: .rect(cornerRadius: 18))
                    .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 9, y: 6)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func row(_ e: Entry, _ p: Palette) -> some View {
        let other: Account? = e.kind == .income ? e.from : e.to
        let title: String
        let sub: String
        switch e.kind {
        case .expense:
            title = e.to?.name ?? (e.note.isEmpty ? "Expense" : e.note)
            sub = "From \(describe(e.from))"
        case .income:
            title = e.from?.name ?? (e.note.isEmpty ? "Income" : e.note)
            sub = "Into \(describe(e.to))"
        case .transfer:
            title = "Transfer"
            sub = "\(describe(e.from)) to \(describe(e.to))"
        }
        let note = !e.note.isEmpty && title != e.note ? " · \(e.note)" : ""
        let amount: String = switch e.kind {
        case .expense: Money.peso(-e.amountCentavos)
        case .income: Money.peso(e.amountCentavos, signed: true)
        case .transfer: Money.peso(e.amountCentavos)
        }
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11)
                .fill(Color(hex: other?.colorHex ?? "#3F3F46"))
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.outfit(15, .semibold)).lineLimit(1)
                Text(sub + note).font(.outfit(12)).foregroundStyle(p.muted).lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(amount)
                .font(.barlow(20))
                .monospacedDigit()
                .foregroundStyle(e.kind == .transfer ? p.muted : p.fg)
        }
        .padding(.horizontal, 14)
        .frame(height: 58)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    /// "GCash •• 4821", or "Mama's GCash •• 2290" for someone else's account.
    private func describe(_ a: Account?) -> String {
        guard let a else { return "—" }
        var s = a.name
        if let owner = a.owner, !owner.isMe { s = "\(owner.name)'s \(s)" }
        if !a.last4.isEmpty { s += " •• \(a.last4)" }
        return s
    }

    /// Income minus expense for the day. Transfers don't change it.
    private func dayTotal(_ list: [Entry]) -> Int {
        list.reduce(0) { sum, e in
            switch e.kind {
            case .income: sum + e.amountCentavos
            case .expense: sum - e.amountCentavos
            case .transfer: sum
            }
        }
    }

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func newEntry() {
        if Setup.Readiness(accounts: accounts).isReady {
            showEntry = true
        } else {
            showSetup = true
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
