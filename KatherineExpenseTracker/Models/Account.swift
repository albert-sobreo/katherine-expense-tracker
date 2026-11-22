import Foundation
import SwiftData

enum AccountKind: String, Codable, CaseIterable {
    /// Money you have: bank, e-wallet or cash.
    case debit
    /// Money you owe. Purchases raise the balance owed; paying the bill is a transfer into it.
    case credit
}

@Model
final class Account {
    var name: String = ""
    /// Last four digits shown as "•• 1234". Empty when the account has none.
    var last4: String = ""
    /// The tile color, e.g. "#007DFE" for GCash.
    var colorHex: String = "#3F3F46"
    var kindRaw: String = AccountKind.debit.rawValue
    /// Credit cards only, in centavos.
    var creditLimitCentavos: Int?
    /// Credit cards only: the day of the month the bill is due.
    var dueDay: Int?
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    var owner: Person?

    @Relationship(deleteRule: .nullify, inverse: \Entry.from)
    var outgoing: [Entry]? = []

    @Relationship(deleteRule: .nullify, inverse: \Entry.to)
    var incoming: [Entry]? = []

    var kind: AccountKind {
        get { AccountKind(rawValue: kindRaw) ?? .debit }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String, last4: String = "", colorHex: String, kind: AccountKind = .debit, owner: Person? = nil) {
        self.name = name
        self.last4 = last4
        self.colorHex = colorHex
        self.kindRaw = kind.rawValue
        self.owner = owner
    }
}
