import AppIntents

/// The phrases Siri knows without any setup. Each one has to say the app's name.
/// The account names in phrases refresh when accounts change (ContentView calls updateAppShortcutParameters).
nonisolated struct KuartaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogExpenseIntent(), phrases: [
            "Log an expense in \(.applicationName)",
            "Add an expense in \(.applicationName)",
            "Log a \(\.$from) expense in \(.applicationName)",
            "Log an expense from \(\.$from) in \(.applicationName)",
            "Add a \(\.$from) expense in \(.applicationName)",
        ], shortTitle: "Log Expense", systemImageName: "minus.circle")

        AppShortcut(intent: LogIncomeIntent(), phrases: [
            "Log income in \(.applicationName)",
            "Add income in \(.applicationName)",
            "Log income into \(\.$into) in \(.applicationName)",
        ], shortTitle: "Log Income", systemImageName: "plus.circle")

        AppShortcut(intent: LogTransferIntent(), phrases: [
            "Log a transfer in \(.applicationName)",
            "Move money in \(.applicationName)",
            "Log a transfer from \(\.$from) in \(.applicationName)",
        ], shortTitle: "Log Transfer", systemImageName: "arrow.left.arrow.right.circle")

        AppShortcut(intent: GetBalanceIntent(), phrases: [
            "What's my balance in \(.applicationName)",
            "Check my balance in \(.applicationName)",
            "What's my net balance in \(.applicationName)",
        ], shortTitle: "Net Balance", systemImageName: "banknote")

        AppShortcut(intent: GetAccountBalanceIntent(), phrases: [
            "What's my \(\.$account) balance in \(.applicationName)",
            "How much is in \(\.$account) in \(.applicationName)",
            "Check \(\.$account) in \(.applicationName)",
        ], shortTitle: "Account Balance", systemImageName: "creditcard")

        AppShortcut(intent: GetMonthSpendingIntent(), phrases: [
            "How much did I spend in \(.applicationName)",
            "How much have I spent this month in \(.applicationName)",
            "How much budget is left in \(.applicationName)",
        ], shortTitle: "Spent This Month", systemImageName: "chart.bar")

        AppShortcut(intent: NewEntryIntent(), phrases: [
            "New entry in \(.applicationName)",
            "Open a new entry in \(.applicationName)",
        ], shortTitle: "New Entry", systemImageName: "square.and.pencil")
    }
}
