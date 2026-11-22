import SwiftUI
import SwiftData

/// Spreadsheet view of a month's entries, like Kath's Excel sheet but phone-width:
/// Date | Item · Account | Amount, two lines per row, no sideways scrolling.
/// The header and the TOTAL row stay pinned while scrolling. Tap a row to edit it.
/// With `account`, it's that account's transactions (all months), signed from the account's side,
/// with a small Edit button for the account itself.
struct EntriesView: View {
    var month: Date? = nil
    var account: Account? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Entry.date, order: .reverse) private var entries: [Entry]
    @Query(sort: \Account.sortOrder) private var allAccounts: [Account]

    @State private var filter: EntryKind?
    @State private var editing: Entry?
    @State private var showNew = false
    @State private var editingAccount: Account?
    @State private var query = ""
    /// The search actually applied, 300 ms after typing stops.
    @State private var appliedQuery = ""
    /// Month view only: show just one account's rows.
    @State private var accountFilter: Account?
    /// Account view only: the month shown. Nil shows all time.
    @State private var pickedMonth: Date? = EntriesView.startOfMonth(.now)
    @State private var showMonthSheet = false

    /// Dates of this account's entries, for the month picker.
    private var accountEntryDates: [Date] {
        guard let id = account?.persistentModelID else { return [] }
        return entries.filter { $0.from?.persistentModelID == id || $0.to?.persistentModelID == id }.map(\.date)
    }

    private static func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    /// The month the rows are limited to, if any.
    private var activeMonth: Date? { account != nil ? pickedMonth : month }

    private let dateWidth: CGFloat = 64
    private let amountWidth: CGFloat = 96
    private let rowHeight: CGFloat = 54

    private var rows: [Entry] {
        let cal = Calendar.current
        let id = account?.persistentModelID
        let q = appliedQuery.trimmingCharacters(in: .whitespaces)
        return entries.filter { e in
            if let m = activeMonth, !cal.isDate(e.date, equalTo: m, toGranularity: .month) { return false }
            if let id, e.from?.persistentModelID != id, e.to?.persistentModelID != id { return false }
            if let f = accountFilter?.persistentModelID, e.from?.persistentModelID != f, e.to?.persistentModelID != f { return false }
            if filter != nil && e.kind != filter { return false }
            if !q.isEmpty {
                let t = EntriesView.text(for: e)
                let hay = [t.item, t.sub, e.note, Money.number(e.amountCentavos)]
                if !hay.contains(where: { $0.localizedCaseInsensitiveContains(q) }) { return false }
            }
            return true
        }
    }

    /// Money into this account (account view) or Kath's income (month view).
    private func isIn(_ e: Entry) -> Bool {
        if let account { return e.to?.persistentModelID == account.persistentModelID }
        return e.kind == .income
    }

    private func isOut(_ e: Entry) -> Bool {
        if let account { return e.from?.persistentModelID == account.persistentModelID }
        return e.kind == .expense
    }

    private var moneyIn: Int { rows.filter(isIn).reduce(0) { $0 + $1.amountCentavos } }
    private var moneyOut: Int { rows.filter(isOut).reduce(0) { $0 + $1.amountCentavos } }

    private var total: (label: String, value: String) {
        if account != nil { return ("In minus out", Money.peso(moneyIn - moneyOut, signed: true)) }
        return switch filter {
        case nil: ("In minus out", Money.peso(moneyIn - moneyOut, signed: true))
        case .expense: ("Expense", Money.peso(-moneyOut))
        case .income: ("Income", Money.peso(moneyIn, signed: true))
        case .transfer: ("Moved", Money.peso(rows.reduce(0) { $0 + $1.amountCentavos }))
        }
    }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 14) {
            header(p)
            if account != nil { monthPicker(p) }
            filterSwitch(p)
            searchRow(p)
            summary(p)
            sheet(p)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .foregroundStyle(p.fg)
        .background(p.bg)
        #if os(iOS)
        .sheet(item: $editingAccount) { AccountForm(editing: $0) }
        .sheet(isPresented: $showMonthSheet) {
            MonthPickerSheet(selection: $pickedMonth, entryDates: accountEntryDates, allowsAllTime: true)
        }
        .onChange(of: editingAccount) { _, new in
            // Deleting the account from its edit form closes this screen too.
            if new == nil, let account, account.modelContext == nil || account.isDeleted { dismiss() }
        }
        .fullScreenCover(item: $editing) { EntryView(editing: $0) }
        .fullScreenCover(isPresented: $showNew) { EntryView() }
        #else
        .sheet(item: $editing) { EntryView(editing: $0).frame(minWidth: 420, minHeight: 760) }
        .sheet(isPresented: $showNew) { EntryView().frame(minWidth: 420, minHeight: 760) }
        #endif
    }

    // MARK: Top

    private func header(_ p: Palette) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(p.chip, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Spacer()
            if let account {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(hex: account.colorHex))
                        .frame(width: 18, height: 18)
                    Text(EntriesView.describe(account)).font(.outfit(17, .bold)).lineLimit(1)
                }
                Spacer()
                Button { editingAccount = account } label: {
                    Text("Edit")
                        .font(.outfit(13, .semibold))
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(p.chip, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit account")
            } else if let month {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(month.formatted(.dateTime.month(.wide))).font(.outfit(17, .bold))
                    Text(month.formatted(.dateTime.year())).font(.barlow(17, .medium)).foregroundStyle(p.muted)
                }
                Spacer()
            } else {
                Text("All entries").font(.outfit(17, .bold))
                Spacer()
            }
            Button { showNew = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(p.bg)
                    .frame(width: 36, height: 36)
                    .background(p.fg, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("New entry")
        }
        .frame(height: 40)
    }

    /// ‹ November 2026 › — arrows step a month, tapping the name picks a month or All time.
    private func monthPicker(_ p: Palette) -> some View {
        let cal = Calendar.current
        let thisMonth = EntriesView.startOfMonth(.now)
        let current = pickedMonth ?? thisMonth
        let atLatest = pickedMonth.map { cal.isDate($0, equalTo: thisMonth, toGranularity: .month) } ?? true
        return HStack {
            Button {
                pickedMonth = cal.date(byAdding: .month, value: -1, to: current)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")
            Spacer()
            Button { showMonthSheet = true } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if let m = pickedMonth {
                        Text(m.formatted(.dateTime.month(.wide))).font(.outfit(15, .semibold))
                        Text(m.formatted(.dateTime.year())).font(.barlow(16, .medium)).foregroundStyle(p.muted)
                    } else {
                        Text("All time").font(.outfit(15, .semibold))
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(p.muted)
                }
                .foregroundStyle(p.fg)
                .contentShape(.rect)
            }
            .accessibilityLabel("Pick month")
            .buttonStyle(.plain)
            Spacer()
            Button {
                if let next = cal.date(byAdding: .month, value: 1, to: current) { pickedMonth = next }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(atLatest)
            .opacity(atLatest ? 0.3 : 1)
            .accessibilityLabel("Next month")
        }
        .frame(height: 40)
        .background(p.card, in: .rect(cornerRadius: 14))
    }

    private func filterSwitch(_ p: Palette) -> some View {
        let options: [EntryKind?] = [nil, .expense, .income, .transfer]
        return HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                let on = filter == option
                Button { withAnimation(.easeOut(duration: 0.15)) { filter = option } } label: {
                    Text(option.map { $0.rawValue.uppercased() } ?? "ALL")
                        .font(.outfit(12, .semibold)).tracking(1.4)
                        .foregroundStyle(on ? p.fg : p.muted)
                        .frame(maxWidth: .infinity).frame(height: 32)
                        .background(on ? p.card : .clear, in: .rect(cornerRadius: 11))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(p.chip, in: .rect(cornerRadius: 14))
    }

    /// Search by item, account, note or amount; in the month view, also narrow to one account.
    private func searchRow(_ p: Palette) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(p.muted)
                TextField("Search", text: $query)
                    .font(.outfit(15))
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = ""; appliedQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(p.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(p.card, in: .rect(cornerRadius: 12))
            .task(id: query) {
                // Debounce: wait for a pause in typing before filtering.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                appliedQuery = query
            }

            if account == nil {
                Menu {
                    Button("All accounts") { accountFilter = nil }
                    ForEach(allAccounts) { a in
                        Button(EntriesView.describe(a)) { accountFilter = a }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let a = accountFilter {
                            RoundedRectangle(cornerRadius: 3).fill(Color(hex: a.colorHex)).frame(width: 10, height: 10)
                            Text(a.name).font(.outfit(13, .semibold)).lineLimit(1)
                        } else {
                            Image(systemName: "line.3.horizontal.decrease")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Account").font(.outfit(13, .semibold))
                        }
                    }
                    .foregroundStyle(accountFilter == nil ? p.muted : p.fg)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .frame(maxWidth: 140)
                    .background(p.card, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accountFilter.map { "Account: \($0.name)" } ?? "Filter by account")
            }
        }
    }

    private func summary(_ p: Palette) -> some View {
        HStack(spacing: 0) {
            if let account, !account.isPayee {
                stat(account.kind == .credit ? "Owed" : "Balance",
                     Money.peso(account.kind == .credit ? -account.balanceCentavos : account.balanceCentavos), p)
            } else {
                stat("Rows", "\(rows.count)", p)
            }
            Rectangle().fill(p.line).frame(width: 1, height: 26)
            stat("In", Money.peso(moneyIn), p)
            Rectangle().fill(p.line).frame(width: 1, height: 26)
            stat("Out", Money.peso(moneyOut), p)
        }
    }

    private func stat(_ label: String, _ value: String, _ p: Palette) -> some View {
        VStack(spacing: 1) {
            Text(label.uppercased()).font(.outfit(10, .semibold)).tracking(1.6).foregroundStyle(p.muted)
            Text(value).font(.barlow(20)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Sheet

    private func sheet(_ p: Palette) -> some View {
        let dark = scheme == .dark
        let grid = p.chip
        let head = Color(hex: dark ? "#231B24" : "#FAF9FA")
        let stripe = Color(hex: dark ? "#211922" : "#FBFAFB")
        let list = rows
        let cal = Calendar.current
        // Band rows by day, and show the date only on a day's first row.
        var band = 0
        var bands: [Int] = []
        for (i, e) in list.enumerated() {
            if i > 0 && !cal.isDate(e.date, inSameDayAs: list[i - 1].date) { band = 1 - band }
            bands.append(band)
        }
        return ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders, .sectionFooters]) {
                Section {
                    ForEach(Array(list.enumerated()), id: \.element.persistentModelID) { i, e in
                        let firstOfDay = i == 0 || !cal.isDate(e.date, inSameDayAs: list[i - 1].date)
                        let lastOfDay = i == list.count - 1 || !cal.isDate(e.date, inSameDayAs: list[i + 1].date)
                        Button { editing = e } label: {
                            row(e, firstOfDay: firstOfDay, lastOfDay: lastOfDay,
                                bg: bands[i] == 1 ? stripe : p.card, grid: grid, p: p)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edit")
                    }
                    addRow(grid: grid, p: p)
                } header: {
                    HStack(spacing: 0) {
                        headCell("Date", .leading).frame(width: dateWidth)
                        Rectangle().fill(grid).frame(width: 1)
                        headCell("Item · Account", .leading)
                        Rectangle().fill(grid).frame(width: 1)
                        headCell("Amount", .trailing).frame(width: amountWidth)
                    }
                    .frame(height: 32)
                    .foregroundStyle(p.muted)
                    .background(head)
                    .overlay(alignment: .bottom) { Rectangle().fill(grid).frame(height: 1) }
                } footer: {
                    let t = total
                    HStack(spacing: 0) {
                        headCell("Total", .leading).frame(width: dateWidth)
                            .foregroundStyle(p.muted)
                        Rectangle().fill(grid).frame(width: 1)
                        Text(t.label).font(.outfit(12)).foregroundStyle(p.muted)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Rectangle().fill(grid).frame(width: 1)
                        Text(t.value).font(.barlow(18, .bold)).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .padding(.horizontal, 12)
                            .frame(width: amountWidth, alignment: .trailing)
                    }
                    .frame(height: 40)
                    .background(head)
                    .overlay(alignment: .top) { Rectangle().fill(grid).frame(height: 1) }
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(p.card)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(grid, lineWidth: 1))
        .shadow(color: .black.opacity(dark ? 0 : 0.05), radius: 9, y: 6)
    }

    private func headCell(_ text: String, _ alignment: Alignment) -> some View {
        Text(text.uppercased())
            .font(.outfit(10, .semibold)).tracking(1.2)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    private func row(_ e: Entry, firstOfDay: Bool, lastOfDay: Bool, bg: Color, grid: Color, p: Palette) -> some View {
        let text = EntriesView.text(for: e)
        let other: Account? = e.kind == .income ? e.from : e.to
        // In an account's view, the sign is from the account's side: money in +, money out −.
        let signed = account != nil
        let amount: String
        if signed {
            amount = (isIn(e) ? "+" : "−") + Money.number(e.amountCentavos)
        } else {
            switch e.kind {
            case .expense: amount = "−" + Money.number(e.amountCentavos)
            case .income: amount = "+" + Money.number(e.amountCentavos)
            case .transfer: amount = Money.number(e.amountCentavos)
            }
        }
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                if firstOfDay {
                    Text(e.date.formatted(.dateTime.day())).font(.barlow(18)).monospacedDigit()
                    Text((activeMonth == nil ? e.date.formatted(.dateTime.month(.abbreviated)) : e.date.formatted(.dateTime.weekday(.abbreviated))).uppercased())
                        .font(.outfit(10, .semibold)).tracking(0.8).foregroundStyle(p.muted)
                }
            }
            .padding(.leading, 10).padding(.top, 9)
            .frame(width: dateWidth, height: rowHeight, alignment: .topLeading)
            .overlay(alignment: .bottom) { if lastOfDay { Rectangle().fill(grid).frame(height: 1) } }

            Rectangle().fill(grid).frame(width: 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(text.item).font(.outfit(14, .semibold)).lineLimit(1)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: other?.colorHex ?? e.from?.colorHex ?? "#3F3F46"))
                        .frame(width: 8, height: 8)
                    Text(text.sub).font(.outfit(12)).foregroundStyle(p.muted).lineLimit(1)
                }
            }
            .padding(.horizontal, 12).padding(.top, 9)
            .frame(maxWidth: .infinity, maxHeight: rowHeight, alignment: .topLeading)
            .overlay(alignment: .bottom) { Rectangle().fill(grid).frame(height: 1) }

            Rectangle().fill(grid).frame(width: 1)

            VStack(alignment: .trailing, spacing: 3) {
                Text(amount)
                    .font(.barlow(18)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(e.kind == .transfer && !signed ? p.muted : p.fg)
                Text(e.kind.rawValue.uppercased())
                    .font(.outfit(10, .semibold)).tracking(1)
                    .foregroundStyle(p.muted)
            }
            .padding(.horizontal, 12).padding(.top, 9)
            .frame(width: amountWidth, height: rowHeight, alignment: .topTrailing)
            .overlay(alignment: .bottom) { Rectangle().fill(grid).frame(height: 1) }
        }
        .frame(height: rowHeight)
        .background(bg)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private func addRow(grid: Color, p: Palette) -> some View {
        Button { showNew = true } label: {
            HStack(spacing: 0) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(p.muted)
                    .frame(width: 24, height: 24)
                    .background(p.chip, in: .rect(cornerRadius: 8))
                    .frame(width: dateWidth)
                Rectangle().fill(grid).frame(width: 1)
                Text("Add a row").font(.outfit(13)).foregroundStyle(p.muted)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: Text

    /// Item on the first line, account (and note) on the second.
    static func text(for e: Entry) -> (item: String, sub: String) {
        var item: String
        var sub: String
        switch e.kind {
        case .expense:
            item = e.to?.name ?? (e.note.isEmpty ? "Expense" : e.note)
            sub = describe(e.from)
        case .income:
            item = e.from?.name ?? (e.note.isEmpty ? "Income" : e.note)
            sub = describe(e.to)
        case .transfer:
            item = "To \(describe(e.to))"
            sub = "From \(describe(e.from))"
        }
        if !e.note.isEmpty && item != e.note { sub += " · \(e.note)" }
        return (item, sub)
    }

    /// "GCash •• 4821", or "Mama's GCash •• 2290" for someone else's account.
    static func describe(_ a: Account?) -> String {
        guard let a else { return "—" }
        var s = a.name
        if let owner = a.owner, !owner.isMe { s = "\(owner.name)'s \(s)" }
        if !a.last4.isEmpty { s += " •• \(a.last4)" }
        return s
    }
}

#Preview {
    EntriesView(month: .now)
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
