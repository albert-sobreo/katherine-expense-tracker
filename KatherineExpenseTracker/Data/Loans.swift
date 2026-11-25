import Foundation
import SwiftData

extension Entry {
    /// For a transfer marked as a loan between one of Kath's accounts and someone else's:
    /// that someone (the other account's owner). Nil for anything else.
    var loanPerson: Person? {
        guard isLoan, kind == .transfer else { return nil }
        if from?.isMine == true, let o = to?.owner, !o.isMe, to?.isPayee == false, to?.isLoan == false { return o }
        if to?.isMine == true, let o = from?.owner, !o.isMe, from?.isPayee == false, from?.isLoan == false { return o }
        return nil
    }

    /// What this loan transfer adds to what the person owes Kath: lending is +, borrowing is −.
    var loanEffect: Int {
        guard loanPerson != nil else { return 0 }
        return from?.isMine == true ? amountCentavos : -amountCentavos
    }
}

/// One row on the Loans screen: a person Kath has loan transfers with, a loan tile, or both
/// when the tile has the person's name. Balance above zero: they owe Kath; below: Kath owes them.
struct LoanLine: Identifiable {
    let id: String
    let name: String
    let colorHex: String
    /// The loan tile, if there is one.
    let tile: Account?
    /// The person, if there are loan transfers with them.
    let person: Person?
    let balance: Int
    let lastDate: Date?

    var status: String { balance > 0 ? "Owes you" : (balance < 0 ? "You owe" : "Even") }

    static let personColor = "#6B5B6E"

    /// The loan transfers with this person plus everything on the tile, newest first.
    func entries(from all: [Entry]) -> [Entry] {
        let pid = person?.persistentModelID
        let tid = tile?.persistentModelID
        return all.filter { e in
            if let pid, e.loanPerson?.persistentModelID == pid { return true }
            if let tid, e.from?.persistentModelID == tid || e.to?.persistentModelID == tid { return true }
            return false
        }
        .sorted { $0.date > $1.date }
    }

    /// Every loan, biggest amount first inside each direction.
    static func all(accounts: [Account], entries: [Entry]) -> [LoanLine] {
        var byPerson: [PersistentIdentifier: (person: Person, balance: Int, last: Date)] = [:]
        for e in entries {
            guard let person = e.loanPerson else { continue }
            let id = person.persistentModelID
            let old = byPerson[id]
            byPerson[id] = (person, (old?.balance ?? 0) + e.loanEffect, max(old?.last ?? .distantPast, e.date))
        }
        var lines: [LoanLine] = []
        var usedPeople = Set<PersistentIdentifier>()
        for tile in accounts where tile.isLoan {
            let match = byPerson.values.first { $0.person.name.lowercased() == tile.name.lowercased() }
            if let match { usedPeople.insert(match.person.persistentModelID) }
            let tileLast = ((tile.outgoing ?? []) + (tile.incoming ?? [])).map(\.date).max()
            let last = [tileLast, match?.last].compactMap { $0 }.max()
            lines.append(LoanLine(id: "tile-\(tile.persistentModelID.hashValue)", name: tile.name, colorHex: tile.colorHex,
                                  tile: tile, person: match?.person,
                                  balance: tile.balanceCentavos + (match?.balance ?? 0), lastDate: last))
        }
        for (id, v) in byPerson where !usedPeople.contains(id) {
            lines.append(LoanLine(id: "person-\(id.hashValue)", name: v.person.name, colorHex: personColor,
                                  tile: nil, person: v.person, balance: v.balance, lastDate: v.last))
        }
        return lines.sorted { abs($0.balance) != abs($1.balance) ? abs($0.balance) > abs($1.balance) : $0.name < $1.name }
    }
}

extension LoanLine {
    /// What a sheet needs to find a loan row again, so it stays live as entries change.
    struct Ref: Identifiable {
        let id: String
        let name: String
        let tile: Account?
        let person: Person?
        init(line: LoanLine) { id = line.id; name = line.name; tile = line.tile; person = line.person }
    }
}
