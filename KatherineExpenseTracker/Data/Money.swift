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

    var isMine: Bool { owner?.isMe == true && !isPayee && !isLoan }

    /// A bank, wallet or card picked for Home (Settings > Accounts on Home). Payees and loans never count.
    var countsOnHome: Bool { !isPayee && !isLoan && showOnHome }

    /// "Owes you", "You owe" or "Even" for a loan tile.
    var loanStatus: String {
        let b = balanceCentavos
        return b > 0 ? "Owes you" : (b < 0 ? "You owe" : "Even")
    }
}

extension Entry {
    /// Spending for Home: paid from an account on Home to somewhere that isn't one
    /// (money moved between two Home accounts is neither spent nor earned).
    var countsAsExpense: Bool { kind == .expense && from?.countsOnHome == true && to?.countsOnHome != true }
    /// Income for Home: into an account on Home from somewhere that isn't one.
    var countsAsIncome: Bool { kind == .income && to?.countsOnHome == true && from?.countsOnHome != true }
}

/// Home's numbers for a month, from the accounts picked for Home (all of them unless changed in Settings).
struct MonthTotals {
    var income = 0
    var expense = 0

    init(entries: [Entry], month: Date, calendar: Calendar = .current) {
        for e in entries where calendar.isDate(e.date, equalTo: month, toGranularity: .month) {
            if e.countsAsIncome { income += e.amountCentavos }
            if e.countsAsExpense { expense += e.amountCentavos }
        }
    }

    /// Net balance: everything in the Home accounts minus what's owed on cards among them,
    /// plus loans (money lent is still hers, money borrowed is debt). Not month-bound.
    static func netBalance(_ accounts: [Account]) -> Int {
        let home = accounts.filter { $0.countsOnHome || $0.isLoan }.reduce(0) { $0 + $1.balanceCentavos }
        // Loan transfers with someone whose account isn't on Home: the money moved is already in the
        // total, so add the debt too (lent money is still hers, borrowed money is owed).
        var debts = 0
        for a in accounts where a.countsOnHome {
            for e in a.outgoing ?? [] where e.loanPerson != nil && e.to?.countsOnHome != true { debts += e.amountCentavos }
            for e in a.incoming ?? [] where e.loanPerson != nil && e.from?.countsOnHome != true { debts -= e.amountCentavos }
        }
        return home + debts
    }
}
