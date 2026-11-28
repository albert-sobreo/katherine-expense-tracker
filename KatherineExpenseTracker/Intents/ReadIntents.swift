import Foundation
import AppIntents
import SwiftData

/// "What's my balance in Kuarta": the net balance from Home.
nonisolated struct GetBalanceIntent: AppIntent {
    static var title: LocalizedStringResource { "Get Net Balance" }
    static var description: IntentDescription {
        IntentDescription("Tells you your net balance: what's in your accounts minus card debt, plus loans.")
    }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let net = MonthTotals.netBalance(IntentStore.accounts())
        return .result(value: Double(net) / 100, dialog: "Your net balance is \(Money.peso(net)).")
    }
}

/// "What's my GCash balance in Kuarta": one account's balance.
nonisolated struct GetAccountBalanceIntent: AppIntent {
    static var title: LocalizedStringResource { "Get Account Balance" }
    static var description: IntentDescription {
        IntentDescription("Tells you how much is in one account, what you owe on a card, or where a loan stands.")
    }

    @Parameter(title: "Account", requestValueDialog: "Which account?")
    var account: AccountEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get the balance of \(\.$account)")
    }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let all = IntentStore.accounts()
        guard let a = all.first(where: { IntentStore.key($0) == account.id }) else { throw KuartaIntentError.notFound }
        let name = IntentStore.label(a)
        var balance = a.balanceCentavos
        let text: String
        if a.isLoan {
            // Same number as the Loans screen: the tile plus loan transfers with a person of that name.
            balance = LoanLine.all(accounts: all, entries: IntentStore.entries())
                .first { $0.tile?.persistentModelID == a.persistentModelID }?.balance ?? balance
            text = balance > 0 ? "\(name) owes you \(Money.peso(balance))."
                : balance < 0 ? "You owe \(name) \(Money.peso(-balance))."
                : "You and \(name) are even."
        } else if a.kind == .credit {
            text = balance <= 0 ? "You owe \(Money.peso(-balance)) on \(name)." : "\(name) has \(Money.peso(balance)) in credit."
        } else {
            text = "\(name) has \(Money.peso(balance))."
        }
        return .result(value: Double(balance) / 100, dialog: "\(text)")
    }
}

/// "How much did I spend in Kuarta": this month's spending and what's left of the budget.
nonisolated struct GetMonthSpendingIntent: AppIntent {
    static var title: LocalizedStringResource { "Get This Month's Spending" }
    static var description: IntentDescription {
        IntentDescription("Tells you how much you've spent this month and how much budget is left.")
    }

    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let now = Date.now
        let month = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
        let spent = MonthTotals(entries: IntentStore.entries(), month: month).expense
        var text = "You've spent \(Money.peso(spent)) this month."
        let budget = IntentStore.budget
        if budget > 0 {
            let left = budget - spent
            text += left >= 0
                ? " \(Money.peso(left)) left of your \(Money.peso(budget)) budget."
                : " That's \(Money.peso(-left)) over your \(Money.peso(budget)) budget."
        }
        return .result(value: Double(spent) / 100, dialog: "\(text)")
    }
}

/// "New entry in Kuarta": opens the app on the entry screen.
nonisolated struct NewEntryIntent: AppIntent {
    static var title: LocalizedStringResource { "New Entry" }
    static var description: IntentDescription { IntentDescription("Opens Kuarta on the entry screen.") }
    static var openAppWhenRun: Bool { true }

    @MainActor func perform() async throws -> some IntentResult {
        IntentRouter.shared.wantsNewEntry = true
        return .result()
    }
}
