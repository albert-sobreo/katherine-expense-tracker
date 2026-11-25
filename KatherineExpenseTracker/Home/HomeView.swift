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
    @State private var showBudget = false
    @State private var showLoans = false
    @State private var showSettings = false
    @State private var repeating: Entry?
    @AppStorage(Budget.key) private var budget = 0
    @Environment(\.openDetail) private var openDetail
    @Environment(\.detailRoute) private var detailRoute

    // On a wide iPad window these open on the right side; otherwise in a sheet.
    private func openEntries() { if let openDetail { openDetail(.entries(month)) } else { showSheet = true } }
    private func openAnalytics() { if let openDetail { openDetail(.analytics(month)) } else { showAnalytics = true } }
    private func openLoans() { if let openDetail { openDetail(.loans) } else { showLoans = true } }
    private func open(_ a: Account) {
        if let openDetail { openDetail(.account(a.persistentModelID)) } else { viewingAccount = a }
    }
    private func isShowing(_ a: Account) -> Bool { detailRoute == .account(a.persistentModelID) }
    private var showingEntries: Bool {
        if case .entries? = detailRoute { return true }
        return false
    }
    private var showingAnalytics: Bool {
        if case .analytics? = detailRoute { return true }
        return false
    }

    /// A header circle button; filled in when its screen is open on the right side.
    private func circleButton(_ icon: String, size: CGFloat = 16, active: Bool = false, _ p: Palette,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(active ? p.bg : p.fg)
                .frame(width: 40, height: 40)
                .background(active ? p.fg : p.chip, in: .circle)
        }
        .buttonStyle(.plain)
    }

    /// A balance tile, outlined while its transactions are open on the right side.
    private func tile(_ a: Account, _ p: Palette) -> some View {
        Button { open(a) } label: {
            BalanceTile(account: a)
                .overlay {
                    if isShowing(a) {
                        RoundedRectangle(cornerRadius: 22).strokeBorder(p.fg, lineWidth: 2.5)
                            .scaleEffect(0.95)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Show transactions")
        .accessibilityAddTraits(isShowing(a) ? .isSelected : [])
    }

    private static func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    private var isThisMonth: Bool { Calendar.current.isDate(month, equalTo: .now, toGranularity: .month) }
    private var totals: MonthTotals { MonthTotals(entries: entries, month: month) }
    private var balanceGroups: [RailGroup] { RailGroup.build(people: people, accounts: accounts) }
    private var loans: [Account] { accounts.filter(\.isLoan) }

    /// The latest 5 entries that differ in type, amount, accounts or note, for "Repeat" on long-press.
    private var recentTemplates: [Entry] {
        var seen = Set<String>()
        var out: [Entry] = []
        for e in entries {
            let key = "\(e.kindRaw)|\(e.amountCentavos)|\(e.from?.name ?? "")|\(e.to?.name ?? "")|\(e.note)"
            if seen.insert(key).inserted { out.append(e) }
            if out.count == 5 { break }
        }
        return out
    }

    /// Steps the month; never past this month.
    private func step(_ months: Int) {
        guard let m = Calendar.current.date(byAdding: .month, value: months, to: month) else { return }
        if months > 0, m > HomeView.startOfMonth(.now) { return }
        withAnimation(.easeOut(duration: 0.2)) { month = m }
    }
    private var hasMyAccount: Bool { Setup.Readiness(accounts: accounts).isReady }

    var body: some View {
        let p = Palette.of(scheme)
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(p)
                    if hasMyAccount {
                        hero(p)
                            .contentShape(.rect)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 30)
                                    .onEnded { v in
                                        // Swipe the totals sideways to change month.
                                        guard abs(v.translation.width) > abs(v.translation.height) * 1.5,
                                              abs(v.translation.width) > 60 else { return }
                                        step(v.translation.width < 0 ? 1 : -1)
                                    }
                            )
                            .sensoryFeedback(.selection, trigger: month)
                    } else {
                        emptyCard(p)
                    }
                    if !balanceGroups.isEmpty { balances(p) }
                    if !loans.isEmpty { loansRow(p) }
                    if hasMyAccount { recent(p) }
                }
                .padding(.bottom, 130)
            }
            .scrollIndicators(.hidden)

            LinearGradient(colors: [p.bg.opacity(0), p.bg], startPoint: .top, endPoint: .init(x: 0.5, y: 0.7))
                .frame(height: 130)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .bottom)

            Button(action: newEntry) {
                Label("New entry", systemImage: "plus")
                    .font(.outfit(13, .semibold)).tracking(2).textCase(.uppercase)
                    .foregroundStyle(p.bg)
                    .padding(.leading, 22).padding(.trailing, 26).frame(height: 60)
                    .background(p.fg, in: .capsule)
                    .shadow(color: .black.opacity(scheme == .dark ? 0.5 : 0.28), radius: 14, y: 12)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
            .contextMenu {
                // Long-press: repeat one of the latest entries with today's date.
                if !recentTemplates.isEmpty {
                    Section("Repeat") {
                        ForEach(recentTemplates) { e in
                            Button {
                                if hasMyAccount { repeating = e } else { showSetup = true }
                            } label: {
                                Text("\(EntriesView.text(for: e).item) · \(Money.peso(e.amountCentavos))")
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 18)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        // Settings is a page (pushed, swipe from the left to go back); everything else is a sheet.
        .navigationDestination(isPresented: $showSettings) {
            SettingsView()
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
        }
        .task(id: WidgetSnapshot.make(entries: entries, accounts: accounts, budget: budget)) {
            // Keep the Home Screen widget's numbers current.
            WidgetSnapshot.make(entries: entries, accounts: accounts, budget: budget).save()
        }
        .onChange(of: month) { _, m in
            // The right side follows Home's month.
            switch detailRoute {
            case .entries?: openDetail?(.entries(m))
            case .analytics?: openDetail?(.analytics(m))
            default: break
            }
        }
        .sheet(isPresented: $showSetup) { NeedsSetupSheet() }
        .sheet(isPresented: $showBudget) { BudgetSheet() }
        .sheet(isPresented: $showMonthSheet) {
            MonthPickerSheet(selection: Binding(get: { month }, set: { if let m = $0 { month = m } }),
                             entryDates: entries.map(\.date))
        }
        .sheet(isPresented: $showAccounts) {
            AccountSetupPage(onDone: { showAccounts = false })
                .presentationDragIndicator(.visible)
        }
        #if os(iOS)
        .sheet(isPresented: $showEntry) { EntryView() }
        .sheet(item: $editingEntry) { entry in EntryView(editing: entry) }
        .sheet(isPresented: $showSheet) { EntriesView(month: month) }
        .sheet(isPresented: $showAnalytics) { AnalyticsView(month: month) }
        .sheet(item: $viewingAccount) { EntriesView(account: $0) }
        .sheet(isPresented: $showLoans) { LoansView() }
        .sheet(item: $repeating) { EntryView(template: $0) }
        #else
        .sheet(item: $editingEntry) { entry in EntryView(editing: entry).frame(minWidth: 420, minHeight: 760) }
        .sheet(isPresented: $showSheet) { EntriesView(month: month).frame(minWidth: 420, minHeight: 760) }
        .sheet(isPresented: $showAnalytics) { AnalyticsView(month: month).frame(minWidth: 420, minHeight: 760) }
        .sheet(item: $viewingAccount) { EntriesView(account: $0).frame(minWidth: 420, minHeight: 760) }
        .sheet(isPresented: $showLoans) { LoansView().frame(minWidth: 420, minHeight: 760) }
        .sheet(item: $repeating) { EntryView(template: $0).frame(minWidth: 420, minHeight: 760) }
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
            circleButton("tablecells", active: showingEntries, p, action: openEntries)
                .accessibilityLabel("Spreadsheet view")
            circleButton("chart.bar", active: showingAnalytics, p, action: openAnalytics)
                .accessibilityLabel("Analytics")
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(p.chip, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
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
            budgetBar(spent: t.expense, p)
            HStack(spacing: 0) {
                stat("Income", Money.peso(t.income), p, color: Color(hex: scheme == .dark ? "#34D399" : "#10B981"))
                Rectangle().fill(p.line).frame(width: 1, height: 30)
                stat("Expense", Money.peso(t.expense), p, color: Color(hex: scheme == .dark ? "#FB7185" : "#F43F5E"))
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

    /// Progress toward the monthly budget, or a small link to set one.
    @ViewBuilder
    private func budgetBar(spent: Int, _ p: Palette) -> some View {
        if budget > 0 {
            let over = spent > budget
            let share = min(Double(spent) / Double(budget), 1)
            let rose = Color(hex: scheme == .dark ? "#FB7185" : "#F43F5E")
            Button { showBudget = true } label: {
                VStack(spacing: 7) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(p.chip)
                            Capsule().fill(over ? rose : p.fg)
                                .frame(width: max(geo.size.width * share, share > 0 ? 6 : 0))
                        }
                    }
                    .frame(height: 6)
                    HStack {
                        Text(over ? "\(Money.peso(spent - budget)) OVER" : "\(Money.peso(budget - spent)) LEFT")
                            .font(.outfit(11, .semibold)).tracking(1.4)
                            .foregroundStyle(over ? rose : p.fg)
                        Spacer()
                        Text("BUDGET \(Money.peso(budget))")
                            .font(.outfit(11, .semibold)).tracking(1.4)
                            .foregroundStyle(p.muted)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 4)
        } else if isThisMonth {
            Button { showBudget = true } label: {
                Label("Set a monthly budget", systemImage: "plus")
                    .font(.outfit(12, .semibold))
                    .foregroundStyle(p.muted)
                    .padding(.horizontal, 12).frame(height: 28)
                    .background(p.chip, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
    }

    private func stat(_ label: String, _ value: String, _ p: Palette, color: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.outfit(10, .semibold)).tracking(1.6)
                .foregroundStyle(p.muted)
            Text(value)
                .font(.barlow(22))
                .monospacedDigit()
                .foregroundStyle(color ?? p.fg)
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
                Button { showAccounts = true } label: {
                    HStack(spacing: 8) {
                        Text("BALANCES").foregroundStyle(p.muted)
                        Text(current.label.uppercased())
                            .foregroundStyle(p.fg)
                            .contentTransition(.opacity)
                            .animation(.easeOut(duration: 0.15), value: current.label)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(p.muted)
                    }
                    .font(.outfit(11, .semibold)).tracking(1.8)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accounts")
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
                        ForEach(g.accounts) { a in tile(a, p) }
                    }
                }
                .padding(.horizontal, 13)
                .padding(.top, 4).padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .trackRailScroll($balanceScroll)
        }
    }

    // MARK: Loans

    /// One tile per person Kath has a loan with, plus what's owed each way.
    private func loansRow(_ p: Palette) -> some View {
        let owedToYou = loans.map(\.balanceCentavos).filter { $0 > 0 }.reduce(0, +)
        let youOwe = -loans.map(\.balanceCentavos).filter { $0 < 0 }.reduce(0, +)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("LOANS").foregroundStyle(p.muted)
                    .font(.outfit(11, .semibold)).tracking(1.8)
                Spacer()
                Button("See all", action: openLoans)
                    .buttonStyle(.plain)
                    .font(.outfit(14, .medium))
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(loans) { a in tile(a, p) }
                }
                .padding(.horizontal, 13)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)
            HStack(spacing: 14) {
                loanStat("Owed to you", owedToYou, p)
                loanStat("You owe", youOwe, p)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }

    private func loanStat(_ label: String, _ value: Int, _ p: Palette) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label).font(.outfit(13)).foregroundStyle(p.muted)
            Text(Money.peso(value)).font(.barlow(16)).monospacedDigit()
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
                Button("See all", action: openEntries)
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
