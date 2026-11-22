import Foundation
import SwiftData

enum EntryKind: String, Codable, CaseIterable {
    case expense
    case income
    case transfer
}

/// One row of Kath's spreadsheet.
///
/// - Expense: `from` is the account that paid, `to` is the payee.
/// - Income: `from` is who paid her, `to` is the account it went into.
/// - Transfer: money moved between two accounts, including paying a credit card bill.
@Model
final class Entry {
    /// Always positive, in centavos (₱350.00 = 35000), to avoid rounding errors.
    var amountCentavos: Int = 0
    var kindRaw: String = EntryKind.expense.rawValue
    var date: Date = Date()
    var note: String = ""
    var createdAt: Date = Date()

    var from: Account?
    var to: Account?

    var kind: EntryKind {
        get { EntryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(amountCentavos: Int, kind: EntryKind, date: Date = Date(), from: Account?, to: Account?, note: String = "") {
        self.amountCentavos = amountCentavos
        self.kindRaw = kind.rawValue
        self.date = date
        self.from = from
        self.to = to
        self.note = note
    }
}
