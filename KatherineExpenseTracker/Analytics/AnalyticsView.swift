import SwiftUI
import SwiftData

/// Analytics for Kath's own money (other people's accounts are not counted):
/// Week / Month / Year switch, spending bars for the period, Income vs spent by month,
/// and simple "Where it went" / "Paid from" tables.
struct AnalyticsView: View {
    @State var month: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Entry.date) private var entries: [Entry]

    @State private var selectedDay: Int?
    @State private var period: Period = .month
    @State private var showMonthSheet = false

    private let cal = Calendar.current

    // MARK: Data

    private func startOfMonth(_ d: Date) -> Date { cal.dateInterval(of: .month, for: d)?.start ?? d }

    /// Kath's expenses (paid from her own accounts) and income (into her own accounts).
    private var myExpenses: [Entry] { entries.filter { $0.kind == .expense && $0.from?.isMine == true } }
    private var myIncome: [Entry] { entries.filter { $0.kind == .income && $0.to?.isMine == true } }

    private func inMonth(_ list: [Entry], _ m: Date) -> [Entry] {
        list.filter { cal.isDate($0.date, equalTo: m, toGranularity: .month) }
    }

    private func sum(_ list: [Entry]) -> Int { list.reduce(0) { $0 + $1.amountCentavos } }

    enum Period: String, CaseIterable { case week = "Week", month = "Month", year = "Year" }

    private var component: Calendar.Component {
        switch period {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }

    /// The week, month or year that contains `month` (the anchor date).
    private var range: DateInterval {
        cal.dateInterval(of: component, for: month) ?? DateInterval(start: month, duration: 86_400 * 30)
    }

    private func inPeriod(_ list: [Entry]) -> [Entry] {
        let r = range
        return list.filter { $0.date >= r.start && $0.date < r.end }
    }

    private func bucketName(_ b: Bucket) -> String {
        period == .year
            ? b.start.formatted(.dateTime.month(.wide))
            : b.start.formatted(.dateTime.month(.abbreviated).day())
    }

    private struct Bucket: Identifiable {
        let id: Int
        let start: Date
        let label: String
        let value: Int
        let future: Bool
    }

    /// Spending per day (week, month) or per month (year).
    private var buckets: [Bucket] {
        let step: Calendar.Component = period == .year ? .month : .day
        let r = range
        var starts: [Date] = []
        var d = r.start
        while d < r.end {
            starts.append(d)
            guard let next = cal.date(byAdding: step, value: 1, to: d) else { break }
            d = next
        }
        let spent = inPeriod(myExpenses)
        return starts.enumerated().map { (i, start) -> Bucket in
            let end = i + 1 < starts.count ? starts[i + 1] : r.end
            let value = spent.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.amountCentavos }
            let label: String = switch period {
            case .week: start.formatted(.dateTime.weekday(.narrow))
            case .month: start.formatted(.dateTime.day())
            case .year: start.formatted(.dateTime.month(.narrow))
            }
            return Bucket(id: i, start: start, label: label, value: value, future: start > .now)
        }
    }

    /// Back to January 2000, or the oldest entry if older.
    private var oldestDate: Date {
        let floor = cal.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? .distantPast
        return min(entries.first?.date ?? floor, floor)
    }
    private var canGoBack: Bool { range.start > oldestDate }
    private var canGoForward: Bool { range.end <= .now }

    private func step(_ by: Int) {
        guard let d = cal.date(byAdding: component, value: by, to: month) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            month = d
            selectedDay = nil
        }
    }

    private var periodTitle: (main: String, sub: String) {
        let r = range
        switch period {
        case .week:
            let last = cal.date(byAdding: .day, value: -1, to: r.end) ?? r.end
            let sameMonth = cal.isDate(r.start, equalTo: last, toGranularity: .month)
            let main = r.start.formatted(.dateTime.month(.abbreviated).day()) + " – "
                + (sameMonth ? last.formatted(.dateTime.day()) : last.formatted(.dateTime.month(.abbreviated).day()))
            return (main, last.formatted(.dateTime.year()))
        case .month:
            return (month.formatted(.dateTime.month(.wide)), month.formatted(.dateTime.year()))
        case .year:
            return (month.formatted(.dateTime.year()), "")
        }
    }

    // MARK: Body

    var body: some View {
        let p = Palette.of(scheme)
        ScrollView {
            VStack(spacing: 18) {
                header(p)
                periodSwitch(p)
                monthBar(p)
                dailyCard(p)
                sixMonthCard(p)
                reportCard("Where it went", rows: whereItWent, p: p)
                reportCard("Paid from", rows: paidFrom, p: p)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .foregroundStyle(p.fg)
        .background(p.bg)
        .sheet(isPresented: $showMonthSheet) {
            MonthPickerSheet(selection: Binding(get: { month }, set: { if let m = $0 { setMonth(m) } }),
                             entryDates: entries.map(\.date))
        }
    }

    private func setMonth(_ m: Date) {
        withAnimation(.easeOut(duration: 0.2)) {
            month = startOfMonth(m)
            period = .month
            selectedDay = nil
        }
    }

    private func header(_ p: Palette) -> some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(p.chip, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Spacer()
            Text("Analytics").font(.outfit(17, .bold))
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .frame(height: 40)
    }

    private func periodSwitch(_ p: Palette) -> some View {
        HStack(spacing: 3) {
            ForEach(Period.allCases, id: \.self) { option in
                let on = period == option
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        // Week of the month being viewed: this week if it's this month, else its first week.
                        if option == .week, cal.isDate(month, equalTo: .now, toGranularity: .month) { month = .now }
                        period = option
                        selectedDay = nil
                    }
                } label: {
                    Text(option.rawValue.uppercased())
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

    private func monthBar(_ p: Palette) -> some View {
        let title = periodTitle
        return HStack {
            arrow("chevron.left", enabled: canGoBack) { step(-1) }
                .accessibilityLabel("Previous \(period.rawValue.lowercased())")
            Spacer()
            Button { if period == .month { showMonthSheet = true } } label: {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(title.main).font(period == .year ? Font.barlow(24) : Font.outfit(20, .bold))
                    if !title.sub.isEmpty {
                        Text(title.sub).font(.barlow(18, .medium)).foregroundStyle(p.muted)
                    }
                }
                .foregroundStyle(p.fg)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title.main) \(title.sub)")
            Spacer()
            arrow("chevron.right", enabled: canGoForward) { step(1) }
                .accessibilityLabel("Next \(period.rawValue.lowercased())")
        }
        .padding(.top, -6)
    }

    private func arrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }

    // MARK: Spent

    private func dailyCard(_ p: Palette) -> some View {
        let dark = scheme == .dark
        let bar = Color(hex: dark ? "#594C5B" : "#A89EA9")
        let items = buckets
        let maxValue = max(items.map(\.value).max() ?? 0, 1)
        let elapsed = max(items.filter { !$0.future }.count, 1)
        let total = items.reduce(0) { $0 + $1.value }
        let average = total / elapsed
        let prevRange = cal.dateInterval(of: component, for: cal.date(byAdding: component, value: -1, to: month) ?? month)
        let prevTotal = prevRange.map { r in myExpenses.filter { $0.date >= r.start && $0.date < r.end }.reduce(0) { $0 + $1.amountCentavos } } ?? 0
        let periodName: String = switch period {
        case .week: "THIS WEEK"
        case .month: month.formatted(.dateTime.month(.wide)).uppercased()
        case .year: month.formatted(.dateTime.year())
        }
        let label: String
        let value: Int
        if let d = selectedDay, items.indices.contains(d) {
            let b = items[d]
            label = period == .year
                ? b.start.formatted(.dateTime.month(.wide)).uppercased()
                : b.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased()
            value = b.value
        } else {
            label = period == .week && !range.contains(.now) ? "SPENT THAT WEEK" : "SPENT IN \(periodName)"
            value = total
        }
        let prevName: String = switch period {
        case .week: "last week"
        case .month: (prevRange?.start ?? month).formatted(.dateTime.month(.abbreviated))
        case .year: (prevRange?.start ?? month).formatted(.dateTime.year())
        }
        let chartHeight: CGFloat = 128

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.outfit(11, .semibold)).tracking(1.8).foregroundStyle(p.muted)
                    Text(Money.peso(value)).font(.barlow(44)).monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
                Spacer()
                if selectedDay == nil, prevTotal > 0 {
                    let change = Double(total - prevTotal) / Double(prevTotal)
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(Int((abs(change) * 100).rounded()))% vs \(prevName)")
                            .font(.outfit(12, .semibold))
                    }
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(p.chip, in: .capsule)
                    .padding(.top, 2)
                    .accessibilityElement(children: .combine)
                }
            }

            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: period == .month ? 3 : 8) {
                    ForEach(items) { b in
                        let on = selectedDay == b.id
                        let h: CGFloat = b.future ? 3 : max(3, chartHeight * CGFloat(b.value) / CGFloat(maxValue))
                        let highlight = on || (selectedDay == nil && b.value == maxValue)
                        let color: Color = b.future ? p.chip : (highlight ? p.fg : bar)
                        Button {
                            guard !b.future else { return }
                            withAnimation(.easeOut(duration: 0.15)) { selectedDay = on ? nil : b.id }
                        } label: {
                            RoundedRectangle(cornerRadius: period == .month ? 4 : 6)
                                .fill(color)
                                .frame(height: h)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(bucketName(b) + ", " + Money.peso(b.value))
                    }
                }
                if average > 0 {
                    let y = chartHeight * CGFloat(average) / CGFloat(maxValue)
                    ZStack(alignment: .trailing) {
                        Line()
                            .stroke(bar, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .frame(height: 1)
                        Text("avg \(Money.short(average))")
                            .font(.barlow(13)).foregroundStyle(p.muted)
                            .padding(.leading, 4)
                            .background(p.card)
                            .offset(y: -9)
                    }
                    .padding(.bottom, y)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .frame(height: chartHeight)

            if period == .month {
                HStack {
                    Text("\(month.formatted(.dateTime.month(.abbreviated))) 1"); Spacer(); Text("8"); Spacer(); Text("15"); Spacer(); Text("22"); Spacer(); Text("\(items.count)")
                }
                .font(.barlow(13, .medium))
                .foregroundStyle(p.muted)
                .accessibilityHidden(true)
            } else {
                HStack(spacing: 8) {
                    ForEach(items) { b in
                        Text(b.label)
                            .font(.outfit(11, .semibold))
                            .foregroundStyle(selectedDay == b.id ? p.fg : p.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 14)
        .background(p.card, in: .rect(cornerRadius: 22))
        .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 9, y: 6)
    }

    // MARK: Income vs spent

    private func sixMonthCard(_ p: Palette) -> some View {
        let dark = scheme == .dark
        // Tailwind emerald and rose: -500 in light, -400 in dark.
        let inc = Color(hex: dark ? "#34D399" : "#10B981")
        let out = Color(hex: dark ? "#FB7185" : "#F43F5E")
        // Every month from the oldest entry (at least the last 12) up to this month, scrolled sideways.
        // Picking a month keeps the whole row and just scrolls to it.
        let thisMonth = startOfMonth(.now)
        let firstMonth = min(startOfMonth(entries.first?.date ?? thisMonth),
                             cal.date(byAdding: .month, value: -11, to: thisMonth) ?? thisMonth,
                             startOfMonth(month))
        let count = (cal.dateComponents([.month], from: firstMonth, to: thisMonth).month ?? 0) + 1
        let months: [Date] = (0..<max(count, 1)).compactMap { cal.date(byAdding: .month, value: $0, to: firstMonth) }
        let data = months.map { m in MonthStat(month: m, income: sum(inMonth(myIncome, m)), spent: sum(inMonth(myExpenses, m))) }
        let maxValue = max(data.map { max($0.income, $0.spent) }.max() ?? 0, 1)
        let barHeight: CGFloat = 100

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("INCOME VS SPENT").font(.outfit(11, .semibold)).tracking(1.8).foregroundStyle(p.muted)
                Spacer()
                HStack(spacing: 12) {
                    legend(inc, "Income")
                    legend(out, "Spent")
                }
                .font(.outfit(12, .medium))
                .foregroundStyle(p.muted)
            }

            ScrollViewReader { proxy in
            ScrollView(.horizontal) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(data) { stat in
                    let m = stat.month, income = stat.income, spent = stat.spent
                    let on = cal.isDate(m, equalTo: month, toGranularity: .month)
                    let saved = income - spent
                    Button { setMonth(m) } label: {
                        VStack(spacing: 6) {
                            Text(income == 0 && spent == 0 ? "" : Money.short(saved))
                                .font(.barlow(13))
                                .foregroundStyle(saved < 0 ? out : p.fg)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            HStack(alignment: .bottom, spacing: 3) {
                                RoundedRectangle(cornerRadius: 4).fill(inc)
                                    .frame(width: 14, height: max(2, barHeight * CGFloat(income) / CGFloat(maxValue)))
                                RoundedRectangle(cornerRadius: 4).fill(out)
                                    .frame(width: 14, height: max(2, barHeight * CGFloat(spent) / CGFloat(maxValue)))
                            }
                            .frame(height: barHeight, alignment: .bottom)
                            Text(m.formatted(.dateTime.month(.abbreviated)).uppercased())
                                .font(.outfit(11, .semibold)).tracking(0.9)
                                .foregroundStyle(on ? p.fg : p.muted)
                        }
                        .padding(.top, 4).padding(.bottom, 6)
                        .frame(width: 48)
                        .background(on ? p.chip.opacity(0.6) : .clear, in: .rect(cornerRadius: 12))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(m.formatted(.dateTime.month(.wide))): income \(Money.peso(income)), spent \(Money.peso(spent))")
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .id(m)
                }
            }
            .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
            .onAppear { proxy.scrollTo(startOfMonth(month), anchor: .center) }
            .onChange(of: month) { _, new in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(startOfMonth(new), anchor: .center) }
            }
            }

            Text("Number above each month = saved (income − spent).")
                .font(.outfit(12)).foregroundStyle(p.muted)
        }
        .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 14)
        .background(p.card, in: .rect(cornerRadius: 22))
        .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 9, y: 6)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 9, height: 9)
            Text(text)
        }
    }

    // MARK: Tables

    private struct MonthStat: Identifiable {
        let month: Date
        let income: Int
        let spent: Int
        var id: Date { month }
    }

    private struct ReportRow: Identifiable {
        let id: String
        let name: String
        let colorHex: String
        let amount: Int
    }

    /// The month's spending grouped by who it went to.
    private var whereItWent: [ReportRow] {
        group(inPeriod(myExpenses)) { e in
            if let to = e.to { return (EntriesView.describe(to), to.colorHex) }
            return (e.note.isEmpty ? "Other" : e.note, "#3F3F46")
        }
    }

    /// The month's spending grouped by the account it was paid from.
    private var paidFrom: [ReportRow] {
        group(inPeriod(myExpenses)) { e in
            (EntriesView.describe(e.from), e.from?.colorHex ?? "#3F3F46")
        }
    }

    private func group(_ list: [Entry], by key: (Entry) -> (String, String)) -> [ReportRow] {
        var totals: [String: (String, Int)] = [:]
        for e in list {
            let (name, color) = key(e)
            totals[name, default: (color, 0)].1 += e.amountCentavos
        }
        return totals.map { ReportRow(id: $0.key, name: $0.key, colorHex: $0.value.0, amount: $0.value.1) }
            .sorted { $0.amount > $1.amount }
    }

    private func reportCard(_ title: String, rows: [ReportRow], p: Palette) -> some View {
        let total = rows.reduce(0) { $0 + $1.amount }
        let sep = scheme == .dark ? p.chip : p.bg
        return VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.outfit(11, .semibold)).tracking(1.8).foregroundStyle(p.muted)
                .padding(.bottom, 4)
            HStack {
                Text("NAME")
                Spacer()
                Text("SHARE").frame(width: 56, alignment: .trailing)
                Text("AMOUNT").frame(width: 92, alignment: .trailing)
            }
            .font(.outfit(10, .semibold)).tracking(1.4).foregroundStyle(p.muted)
            .padding(.bottom, 6)

            if rows.isEmpty {
                Text("No spending in this \(period.rawValue.lowercased()).")
                    .font(.outfit(14)).foregroundStyle(p.muted)
                    .padding(.vertical, 11)
                    .overlay(alignment: .top) { Rectangle().fill(sep).frame(height: 1) }
            }
            ForEach(rows) { r in
                HStack {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 3).fill(Color(hex: r.colorHex)).frame(width: 10, height: 10)
                        Text(r.name).font(.outfit(14, .semibold)).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text("\(Int((Double(r.amount) / Double(max(total, 1)) * 100).rounded()))%")
                        .font(.barlow(16, .medium)).foregroundStyle(p.muted)
                        .frame(width: 56, alignment: .trailing)
                    Text(Money.peso(r.amount))
                        .font(.barlow(18)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(width: 92, alignment: .trailing)
                }
                .padding(.vertical, 11)
                .overlay(alignment: .top) { Rectangle().fill(sep).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
            HStack {
                Text("TOTAL").font(.outfit(11, .semibold)).tracking(1.6)
                Spacer()
                Text(Money.peso(total)).font(.barlow(18, .bold)).monospacedDigit()
            }
            .padding(.vertical, 11)
            .overlay(alignment: .top) { Rectangle().fill(p.fg).frame(height: 1.5) }
        }
        .padding(.horizontal, 16).padding(.top, 18).padding(.bottom, 8)
        .background(p.card, in: .rect(cornerRadius: 22))
        .shadow(color: .black.opacity(scheme == .dark ? 0 : 0.05), radius: 9, y: 6)
    }
}

/// A horizontal line, for the dashed average.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

#Preview {
    AnalyticsView(month: .now)
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
