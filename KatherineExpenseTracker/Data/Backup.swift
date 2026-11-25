import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// A full backup in one JSON file: people, accounts (with balances, colors, owners, card details),
/// entries and the monthly budget. Restoring replaces everything in the app with the file's contents.
struct Backup: Codable {
    struct P: Codable {
        var id: String, name: String, isMe: Bool, sortOrder: Int, createdAt: Date
    }
    struct A: Codable {
        var id: String, name: String, last4: String, colorHex: String, kindRaw: String
        var creditLimitCentavos: Int?, dueDay: Int?
        var isPayee: Bool, isLoan: Bool, showOnHome: Bool
        var openingCentavos: Int, sortOrder: Int, createdAt: Date
        var ownerID: String?
    }
    struct E: Codable {
        var amountCentavos: Int, kindRaw: String, date: Date, note: String, createdAt: Date, isLoan: Bool
        var fromID: String?, toID: String?
    }

    var app = "Katherine"
    var version = 1
    var exportedAt = Date()
    var budget: Int
    var people: [P]
    var accounts: [A]
    var entries: [E]

    var summary: String {
        let shown = accounts.filter { !$0.isPayee }.count
        return "\(shown) \(shown == 1 ? "account" : "accounts"), \(entries.count) \(entries.count == 1 ? "entry" : "entries"), saved \(exportedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    // MARK: Make

    static func make(context: ModelContext, budget: Int) -> Backup {
        let people = (try? context.fetch(FetchDescriptor<Person>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        var ids: [PersistentIdentifier: String] = [:]
        func id(_ m: some PersistentModel) -> String {
            if let s = ids[m.persistentModelID] { return s }
            let s = UUID().uuidString
            ids[m.persistentModelID] = s
            return s
        }
        return Backup(
            budget: budget,
            people: people.map { P(id: id($0), name: $0.name, isMe: $0.isMe, sortOrder: $0.sortOrder, createdAt: $0.createdAt) },
            accounts: accounts.map { a in
                A(id: id(a), name: a.name, last4: a.last4, colorHex: a.colorHex, kindRaw: a.kindRaw,
                  creditLimitCentavos: a.creditLimitCentavos, dueDay: a.dueDay,
                  isPayee: a.isPayee, isLoan: a.isLoan, showOnHome: a.showOnHome,
                  openingCentavos: a.openingCentavos, sortOrder: a.sortOrder, createdAt: a.createdAt,
                  ownerID: a.owner.map { id($0) })
            },
            entries: entries.map { e in
                E(amountCentavos: e.amountCentavos, kindRaw: e.kindRaw, date: e.date, note: e.note,
                  createdAt: e.createdAt, isLoan: e.isLoan, fromID: e.from.map { id($0) }, toID: e.to.map { id($0) })
            })
    }

    func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    static func decode(_ data: Data) throws -> Backup {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(Backup.self, from: data)
    }

    // MARK: Restore

    /// Deletes everything in the app, then loads the backup. The caller sets the budget.
    func restore(into context: ModelContext) {
        for e in (try? context.fetch(FetchDescriptor<Entry>())) ?? [] { context.delete(e) }
        for a in (try? context.fetch(FetchDescriptor<Account>())) ?? [] { context.delete(a) }
        for p in (try? context.fetch(FetchDescriptor<Person>())) ?? [] { context.delete(p) }

        var personByID: [String: Person] = [:]
        for p in people {
            let person = Person(name: p.name, isMe: p.isMe, sortOrder: p.sortOrder)
            person.createdAt = p.createdAt
            context.insert(person)
            personByID[p.id] = person
        }
        var accountByID: [String: Account] = [:]
        for a in accounts {
            let account = Account(name: a.name, last4: a.last4, colorHex: a.colorHex,
                                  kind: AccountKind(rawValue: a.kindRaw) ?? .debit,
                                  owner: a.ownerID.flatMap { personByID[$0] }, isPayee: a.isPayee)
            account.creditLimitCentavos = a.creditLimitCentavos
            account.dueDay = a.dueDay
            account.isLoan = a.isLoan
            account.showOnHome = a.showOnHome
            account.openingCentavos = a.openingCentavos
            account.sortOrder = a.sortOrder
            account.createdAt = a.createdAt
            context.insert(account)
            accountByID[a.id] = account
        }
        for e in entries {
            let entry = Entry(amountCentavos: e.amountCentavos, kind: EntryKind(rawValue: e.kindRaw) ?? .expense,
                              date: e.date, from: e.fromID.flatMap { accountByID[$0] },
                              to: e.toID.flatMap { accountByID[$0] }, note: e.note)
            entry.createdAt = e.createdAt
            entry.isLoan = e.isLoan
            context.insert(entry)
        }
        try? context.save()
        // A backup always has the user's own group, but make sure there's exactly one.
        Setup.me(in: context)
        try? context.save()
    }
}

/// The backup file for the save sheet.
nonisolated struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
