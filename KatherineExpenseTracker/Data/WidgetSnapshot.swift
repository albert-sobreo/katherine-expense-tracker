import Foundation
import WidgetKit

/// Shared with the widget through an App Group. Both targets need the App Groups capability with this ID.
enum AppGroup {
    static let id = "group.katherine.expensetracker"
}

/// The few numbers the Home Screen widget shows. The app writes this whenever the numbers change;
/// the widget only reads it, so it never touches the SwiftData store.
struct WidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable {
        var name: String
        var colorHex: String
        var amount: Int
    }

    /// Start of the month the numbers are for.
    var month: Date
    var spent: Int
    var income: Int
    var net: Int
    /// Biggest payees this month, up to 3.
    var top: [Item]
    /// Monthly budget in centavos, 0 when none is set.
    var budget: Int = 0

    static let key = "widgetSnapshot"

    static func make(entries: [Entry], accounts: [Account], budget: Int = 0, now: Date = .now) -> WidgetSnapshot {
        let cal = Calendar.current
        let month = cal.dateInterval(of: .month, for: now)?.start ?? now
        let totals = MonthTotals(entries: entries, month: month)
        var byPayee: [String: (String, Int)] = [:]
        for e in entries where e.countsAsExpense
            && cal.isDate(e.date, equalTo: month, toGranularity: .month) {
            let name = e.to?.name ?? (e.note.isEmpty ? "Other" : e.note)
            byPayee[name, default: (e.to?.colorHex ?? "#3F3F46", 0)].1 += e.amountCentavos
        }
        let top = byPayee.map { Item(name: $0.key, colorHex: $0.value.0, amount: $0.value.1) }
            .sorted { $0.amount > $1.amount }
            .prefix(3)
        return WidgetSnapshot(month: month, spent: totals.expense, income: totals.income,
                              net: MonthTotals.netBalance(accounts), top: Array(top), budget: budget)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: AppGroup.id),
              let data = try? JSONEncoder().encode(self) else { return }
        if defaults.data(forKey: Self.key) == data { return }
        defaults.set(data, forKey: Self.key)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
