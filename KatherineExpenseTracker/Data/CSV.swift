import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// CSV import and export, so Kath can bring her Excel history in and keep a backup.
///
/// Export columns: Date, Type, Amount, From, To, Note (dates as yyyy-MM-dd).
/// Import reads that, and also common spreadsheet headers: an "Account" column (her own account)
/// plus an "Item"/"Payee"/"Description" column (who it was paid to or received from).
/// Accounts that don't exist yet are created: her own ones under Mine, the rest as payees.
enum CSV {

    // MARK: Parsing

    /// Rows of fields. Handles quotes, escaped quotes ("") and commas or line breaks inside quotes.
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        chars.append("\n")
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 } else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r" || c == "\r\n" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                row.append(field); field = ""
                if !(row.count == 1 && row[0].trimmingCharacters(in: .whitespaces).isEmpty) { rows.append(row) }
                row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        return rows
    }

    /// Quotes a field when it holds a comma, quote or line break.
    static func escape(_ s: String) -> String {
        guard s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: Export

    static func export(_ entries: [Entry]) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        var lines = ["Date,Type,Amount,From,To,Note"]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            let c = e.amountCentavos
            let amount = c % 100 == 0 ? String(c / 100) : String(format: "%.2f", Double(c) / 100)
            // Loan transfers export as "Loan" so they come back as loans on import.
            let type = e.kind == .transfer && e.isLoan ? "Loan" : e.kind.rawValue.capitalized
            let cols = [fmt.string(from: e.date), type, amount,
                        e.from.map { EntriesView.describe($0) } ?? "", e.to.map { EntriesView.describe($0) } ?? "", e.note]
            lines.append(cols.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Import

    struct ImportResult {
        var imported = 0
        var createdAccounts: [String] = []
        var skippedLines: [Int] = []
        /// Rows already in the app (same day, type, amount, accounts and note), left out.
        var duplicates = 0

        var summary: String {
            var parts = ["Imported \(imported) \(imported == 1 ? "entry" : "entries")."]
            if !createdAccounts.isEmpty {
                parts.append("Added \(createdAccounts.count) new: \(createdAccounts.prefix(8).joined(separator: ", "))\(createdAccounts.count > 8 ? "…" : "").")
            }
            if duplicates > 0 {
                parts.append("Left out \(duplicates) row\(duplicates == 1 ? "" : "s") already in the app.")
            }
            if !skippedLines.isEmpty {
                parts.append("Skipped \(skippedLines.count) row\(skippedLines.count == 1 ? "" : "s") that couldn't be read (line \(skippedLines.prefix(10).map(String.init).joined(separator: ", "))\(skippedLines.count > 10 ? "…" : "")).")
            }
            return parts.joined(separator: " ")
        }
    }

    private enum Column { case date, type, amount, from, to, account, other, note }

    private static let headerNames: [Column: [String]] = [
        .date: ["date", "day", "transaction date"],
        .type: ["type", "kind", "transaction type"],
        .amount: ["amount", "amt", "value", "price", "cost", "total"],
        .from: ["from", "paid from", "pay from", "source"],
        .to: ["to", "paid to", "into", "destination"],
        .account: ["account", "bank", "wallet", "card"],
        .other: ["item", "payee", "description", "name", "merchant", "particulars", "category"],
        .note: ["note", "notes", "remarks", "memo", "details", "comment"],
    ]

    private enum Role { case mine, payee }

    static func importText(_ text: String, into context: ModelContext) -> ImportResult {
        var result = ImportResult()
        let rows = parse(text)
        guard !rows.isEmpty else { return result }

        // Work out which column is which from the header row; fall back to the export's order.
        var map: [Column: Int] = [:]
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        for (i, h) in header.enumerated() {
            for (col, names) in headerNames where map[col] == nil && names.contains(h) { map[col] = i }
        }
        let hasHeader = map[.date] != nil && map[.amount] != nil
        if !hasHeader {
            map = [.date: 0, .type: 1, .amount: 2, .from: 3, .to: 4, .note: 5]
        }

        let me = Setup.me(in: context)
        let existing = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        var maxOrder = existing.map(\.sortOrder).max() ?? 0
        var lookup: [String: Account] = [:]
        func remember(_ a: Account) {
            for key in [a.name, EntriesView.describe(a), a.last4.isEmpty ? a.name : "\(a.name) \(a.last4)"] {
                let k = key.lowercased()
                if lookup[k] == nil || (lookup[k]!.isPayee && !a.isPayee) { lookup[k] = a }
            }
        }
        existing.forEach(remember)

        // Entries already in the app, counted by what they contain, so importing the same file twice adds nothing.
        // Counted rather than just noted: two identical coffees on one day in the file still both come in
        // if the app had none.
        let cal = Calendar.current
        func key(_ date: Date, _ kind: EntryKind, _ amount: Int, _ from: Account?, _ to: Account?, _ note: String) -> String {
            let f = from.map { "\($0.persistentModelID.hashValue)" } ?? "-"
            let t = to.map { "\($0.persistentModelID.hashValue)" } ?? "-"
            return "\(cal.startOfDay(for: date).timeIntervalSince1970)|\(kind.rawValue)|\(amount)|\(f)|\(t)|\(note.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
        }
        var already: [String: Int] = [:]
        for e in (try? context.fetch(FetchDescriptor<Entry>())) ?? [] {
            already[key(e.date, e.kind, e.amountCentavos, e.from, e.to, e.note), default: 0] += 1
        }

        func resolve(_ raw: String, as role: Role) -> Account? {
            let name = raw.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            if let a = lookup[name.lowercased()] { return a }
            let presets = role == .payee ? BankPreset.payees + BankPreset.all : BankPreset.all
            let color = presets.first { name.lowercased().hasPrefix($0.name.lowercased()) }?.hex ?? "#3F3F46"
            let a = Account(name: name, colorHex: color, owner: role == .mine ? me : nil, isPayee: role == .payee)
            maxOrder += 1
            a.sortOrder = maxOrder
            context.insert(a)
            remember(a)
            result.createdAccounts.append(name)
            return a
        }

        for (index, row) in rows.enumerated() {
            if index == 0 && hasHeader { continue }
            let line = index + 1
            func value(_ c: Column) -> String {
                guard let i = map[c], i < row.count else { return "" }
                return row[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard let date = parseDate(value(.date)), let signed = parseAmount(value(.amount)), signed != 0 else {
                result.skippedLines.append(line); continue
            }
            let typeText = value(.type).lowercased()
            let loan = typeText.hasPrefix("loan")
            let kind: EntryKind = typeText.hasPrefix("inc") ? .income : (typeText.hasPrefix("tra") || loan ? .transfer : .expense)

            // Direction: explicit From/To columns, or her Account plus the other side (Item/Payee).
            var fromName = value(.from)
            var toName = value(.to)
            if fromName.isEmpty && toName.isEmpty {
                let own = value(.account), other = value(.other)
                switch kind {
                case .expense, .transfer: fromName = own; toName = other
                case .income: fromName = other; toName = own
                }
            }

            let from: Account?
            let to: Account?
            switch kind {
            case .expense:
                from = resolve(fromName, as: .mine); to = resolve(toName, as: .payee)
            case .income:
                from = resolve(fromName, as: .payee); to = resolve(toName, as: .mine)
            case .transfer:
                from = resolve(fromName, as: .mine); to = resolve(toName, as: .mine)
            }
            let ok: Bool = switch kind {
            case .expense: from != nil
            case .income: to != nil
            case .transfer: from != nil && to != nil
            }
            guard ok else { result.skippedLines.append(line); continue }

            var note = value(.note)
            if note.isEmpty, map[.from] == nil, kind == .expense, to == nil { note = value(.other) }
            let k = key(date, kind, abs(signed), from, to, note)
            if let n = already[k], n > 0 {
                already[k] = n - 1
                result.duplicates += 1
                continue
            }
            let entry = Entry(amountCentavos: abs(signed), kind: kind, date: date, from: from, to: to, note: note)
            entry.isLoan = loan
            context.insert(entry)
            result.imported += 1
        }
        try? context.save()
        return result
    }

    /// yyyy-MM-dd, M/d/yyyy and friends, "Nov 22, 2026", or an Excel day number like 45983.
    static func parseDate(_ s: String) -> Date? {
        let text = s.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if let serial = Double(text), serial > 20000, serial < 80000 {
            var c = DateComponents(); c.year = 1899; c.month = 12; c.day = 30
            guard let base = Calendar.current.date(from: c) else { return nil }
            return Calendar.current.date(byAdding: .day, value: Int(serial), to: base)
        }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        for f in ["yyyy-MM-dd", "yyyy/MM/dd", "M/d/yyyy", "M/d/yy", "M-d-yyyy", "MMM d, yyyy", "MMMM d, yyyy",
                  "d MMM yyyy", "d MMMM yyyy", "MMM d yyyy", "yyyy-MM-dd HH:mm:ss", "M/d/yyyy H:mm"] {
            fmt.dateFormat = f
            if let d = fmt.date(from: text) { return d }
        }
        return nil
    }

    /// "₱1,250.50", "PHP 1250", "-300", "(300)" → centavos, with sign.
    static func parseAmount(_ s: String) -> Int? {
        var t = s.replacingOccurrences(of: "₱", with: "")
            .replacingOccurrences(of: "PHP", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "Php", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        var negative = false
        if t.hasPrefix("(") && t.hasSuffix(")") { negative = true; t = String(t.dropFirst().dropLast()) }
        if t.hasPrefix("-") || t.hasPrefix("−") { negative = true; t = String(t.dropFirst()) }
        guard let v = Double(t) else { return nil }
        let c = Int((v * 100).rounded())
        return negative ? -c : c
    }
}

/// A CSV file for the share/export sheet.
nonisolated struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
