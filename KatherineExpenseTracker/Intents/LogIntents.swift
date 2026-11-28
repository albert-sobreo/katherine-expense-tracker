import Foundation
import AppIntents

/// "Log an expense in Kuarta". Saves right away; Siri asks for the amount and account if missing.
nonisolated struct LogExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Expense" }
    static var description: IntentDescription { IntentDescription("Saves an expense in Kuarta right away.") }

    @Parameter(title: "Amount", description: "In pesos", requestValueDialog: "How much?")
    var amount: Double

    @Parameter(title: "Pay From", requestValueDialog: "Pay from which account?")
    var from: AccountEntity

    @Parameter(title: "Paid To")
    var to: PayeeEntity?

    @Parameter(title: "Date", description: "Today if empty")
    var date: Date?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) expense from \(\.$from)") {
            \.$to
            \.$date
            \.$note
        }
    }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let entry = try IntentStore.log(.expense, amount: amount, from: from.id, to: to?.id, date: date, note: note)
        return .result(dialog: "\(IntentStore.summary(entry))")
    }
}

/// "Log income in Kuarta".
nonisolated struct LogIncomeIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Income" }
    static var description: IntentDescription { IntentDescription("Saves income in Kuarta right away.") }

    @Parameter(title: "Amount", description: "In pesos", requestValueDialog: "How much?")
    var amount: Double

    @Parameter(title: "Into", requestValueDialog: "Into which account?")
    var into: AccountEntity

    @Parameter(title: "Received From")
    var from: PayeeEntity?

    @Parameter(title: "Date", description: "Today if empty")
    var date: Date?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) income into \(\.$into)") {
            \.$from
            \.$date
            \.$note
        }
    }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let entry = try IntentStore.log(.income, amount: amount, from: from?.id, to: into.id, date: date, note: note)
        return .result(dialog: "\(IntentStore.summary(entry))")
    }
}

/// "Log a transfer in Kuarta": money moved between two accounts, a card payment, or a loan.
nonisolated struct LogTransferIntent: AppIntent {
    static var title: LocalizedStringResource { "Log Transfer" }
    static var description: IntentDescription {
        IntentDescription("Saves a transfer between two accounts in Kuarta right away, like paying a card bill or lending money.")
    }

    @Parameter(title: "Amount", description: "In pesos", requestValueDialog: "How much?")
    var amount: Double

    @Parameter(title: "From", requestValueDialog: "From which account?")
    var from: AccountEntity

    @Parameter(title: "To", requestValueDialog: "To which account?")
    var to: AccountEntity

    @Parameter(title: "This Is a Loan", description: "Between one of your accounts and someone else's", default: false)
    var isLoan: Bool

    @Parameter(title: "Date", description: "Today if empty")
    var date: Date?

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Move \(\.$amount) from \(\.$from) to \(\.$to)") {
            \.$isLoan
            \.$date
            \.$note
        }
    }

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let entry = try IntentStore.log(.transfer, amount: amount, from: from.id, to: to.id,
                                        date: date, note: note, isLoan: isLoan)
        return .result(dialog: "\(IntentStore.summary(entry))")
    }
}
