import Foundation
import SwiftData
import AppIntents

/// What Siri and Shortcuts read and write. Same rules as the entry screen.
@MainActor
enum IntentStore {
    static var context: ModelContext { AppData.container.mainContext }

    static func accounts() -> [Account] {
        (try? context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
    }

    static func entries() -> [Entry] {
        (try? context.fetch(FetchDescriptor<Entry>())) ?? []
    }

    /// A stable text id for an account, so Siri and saved Shortcuts can find it again.
    static func key(_ a: Account) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(a.persistentModelID))?.base64EncodedString() ?? ""
    }

    static func account(_ id: String) -> Account? {
        accounts().first { key($0) == id }
    }

    /// Banks, wallets and cards (yours first, then other people's), then loans. Most-used first.
    static func holdings() -> [Account] {
        ranked(accounts().filter { !$0.isPayee })
    }

    /// Payees, most-used first.
    static func payees() -> [Account] {
        ranked(accounts().filter(\.isPayee))
    }

    private static func ranked(_ list: [Account]) -> [Account] {
        func group(_ a: Account) -> Int { a.isLoan ? 2 : (a.owner?.isMe == true || a.isPayee ? 0 : 1) }
        func usage(_ a: Account) -> Int { (a.outgoing?.count ?? 0) + (a.incoming?.count ?? 0) }
        return list.sorted { a, b in
            if group(a) != group(b) { return group(a) < group(b) }
            if usage(a) != usage(b) { return usage(a) > usage(b) }
            return a.sortOrder < b.sortOrder
        }
    }

    /// Loose name search: "gcash", "bpi card", "mama bdo".
    static func search(_ list: [Account], _ text: String) -> [Account] {
        let q = NameMatch.normalize(text)
        guard !q.isEmpty else { return list }
        return list
            .map { a -> (Account, Double) in
                var s = NameMatch.score(text, a.name)
                if NameMatch.normalize(a.name).contains(q) { s = max(s, 0.9) }
                if let owner = a.owner, !owner.isMe { s = max(s, NameMatch.score(text, "\(owner.name) \(a.name)")) }
                return (a, s)
            }
            .filter { $0.1 >= 0.6 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// "GCash", or "Mama's BDO" for someone else's account.
    static func label(_ a: Account?) -> String {
        guard let a else { return "" }
        if let owner = a.owner, !owner.isMe, !a.isPayee, !a.isLoan { return "\(owner.name)'s \(a.name)" }
        return a.name
    }

    /// Saves an entry right away, with the entry screen's rules, and refreshes the widget.
    static func log(_ kind: EntryKind, amount: Double, from fromID: String?, to toID: String?,
                    date: Date?, note: String?, isLoan: Bool = false) throws -> Entry {
        let all = accounts()
        guard all.contains(where: { $0.isMine }) else { throw KuartaIntentError.noAccounts }
        guard amount.isFinite, amount >= 0 else { throw KuartaIntentError.badAmount }
        func find(_ id: String?) throws -> Account? {
            guard let id else { return nil }
            guard let a = all.first(where: { key($0) == id }) else { throw KuartaIntentError.notFound }
            return a
        }
        let from = try find(fromID)
        let to = try find(toID)
        switch kind {
        case .expense:
            guard let from, !from.isPayee, !from.isLoan else { throw KuartaIntentError.needsAccount("Pay from") }
        case .income:
            guard let to, !to.isPayee, !to.isLoan else { throw KuartaIntentError.needsAccount("Into") }
        case .transfer:
            guard let from, let to, !from.isPayee, !to.isPayee else { throw KuartaIntentError.needsAccount("From and To") }
            guard from.persistentModelID != to.persistentModelID else { throw KuartaIntentError.sameAccount }
        }
        let entry = Entry(amountCentavos: Int((amount * 100).rounded()), kind: kind, date: date ?? .now,
                          from: from, to: to,
                          note: (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        // Only a transfer between one of your accounts and someone else's can be a loan.
        entry.isLoan = isLoan
        if entry.loanPerson == nil { entry.isLoan = false }
        context.insert(entry)
        try context.save()
        refreshWidget()
        return entry
    }

    /// What Siri says back: "Logged ₱350 from GCash to Grab."
    static func summary(_ e: Entry) -> String {
        let amount = Money.peso(e.amountCentavos)
        var text: String
        switch e.kind {
        case .expense:
            text = "Logged \(amount) from \(label(e.from))" + (e.to.map { " to \(label($0))" } ?? "")
        case .income:
            text = "Logged \(amount) income into \(label(e.to))" + (e.from.map { " from \(label($0))" } ?? "")
        case .transfer:
            text = "Moved \(amount) from \(label(e.from)) to \(label(e.to))"
            if e.isLoan { text += " as a loan" }
        }
        if !Calendar.current.isDateInToday(e.date) {
            text += " on " + e.date.formatted(.dateTime.month(.abbreviated).day())
        }
        return text + "."
    }

    static var budget: Int { UserDefaults.standard.integer(forKey: Budget.key) }

    static func refreshWidget() {
        WidgetSnapshot.make(entries: entries(), accounts: accounts(), budget: budget).save()
    }
}

nonisolated enum KuartaIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noAccounts
    case notFound
    case badAmount
    case needsAccount(String)
    case sameAccount

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noAccounts: "Open Kuarta and add one of your accounts first."
        case .notFound: "That account isn't in Kuarta anymore."
        case .badAmount: "The amount has to be zero or more."
        case .needsAccount(let which): "\(which) needs a bank, wallet or card."
        case .sameAccount: "From and To can't be the same account."
        }
    }
}
