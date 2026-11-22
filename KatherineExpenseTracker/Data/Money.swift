import Foundation

/// Peso formatting. Amounts are stored as Int centavos everywhere.
enum Money {
    /// "₱18,420" or "₱18,420.50". Negative amounts get a real minus: "−₱12,400".
    /// `signed` adds "+" to positive amounts, for income rows.
    static func peso(_ centavos: Int, signed: Bool = false) -> String {
        let sign = centavos < 0 ? "−" : (signed && centavos > 0 ? "+" : "")
        return sign + "₱" + number(abs(centavos))
    }

    /// "18,420" or "18,420.50", no peso sign.
    static func number(_ centavos: Int) -> String {
        let value = Double(abs(centavos)) / 100
        let decimals = centavos % 100 == 0 ? 0 : 2
        return value.formatted(.number.grouping(.automatic).precision(.fractionLength(decimals)))
    }

    /// Short form for tiles: "₱3,240", "₱42.8k", "−₱12.4k".
    static func short(_ centavos: Int) -> String {
        let sign = centavos < 0 ? "−" : ""
        let pesos = Double(abs(centavos)) / 100
        if pesos >= 10_000 {
            let k = (pesos / 100).rounded() / 10
            return sign + "₱" + k.formatted(.number.precision(.fractionLength(0...1))) + "k"
        }
        return sign + "₱" + pesos.rounded().formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
    }
}

extension Account {
    /// Current balance: starting balance, plus money in, minus money out.
    /// For a credit card this is negative: purchases go out of it, paying the bill is a transfer into it.
    var balanceCentavos: Int {
        let moneyIn = (incoming ?? []).reduce(0) { $0 + $1.amountCentavos }
        let moneyOut = (outgoing ?? []).reduce(0) { $0 + $1.amountCentavos }
        return openingCentavos + moneyIn - moneyOut
    }

    var isMine: Bool { owner?.isMe == true && !isPayee }
}

/// Kath's own numbers for a month. Other people's accounts are tracked but never counted here.
struct MonthTotals {
    var income = 0
    var expense = 0

    init(entries: [Entry], month: Date, calendar: Calendar = .current) {
        for e in entries where calendar.isDate(e.date, equalTo: month, toGranularity: .month) {
            switch e.kind {
            case .income where e.to?.isMine == true: income += e.amountCentavos
            case .expense where e.from?.isMine == true: expense += e.amountCentavos
            default: break
            }
        }
    }

    /// Net balance: everything in Kath's own accounts minus what she owes on her cards. Not month-bound.
    static func netBalance(_ accounts: [Account]) -> Int {
        accounts.filter(\.isMine).reduce(0) { $0 + $1.balanceCentavos }
    }
}
