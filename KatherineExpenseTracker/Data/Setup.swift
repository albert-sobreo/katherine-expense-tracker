import Foundation
import SwiftData

enum Setup {
    /// Kath's own group ("Mine"). Created on first launch. If iCloud sync brings in a second
    /// copy from another device, the extra copies are merged into the oldest one.
    @discardableResult
    static func me(in context: ModelContext) -> Person {
        let descriptor = FetchDescriptor<Person>(
            predicate: #Predicate { $0.isMe },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        if let first = all.first {
            for extra in all.dropFirst() {
                for account in extra.accounts ?? [] { account.owner = first }
                context.delete(extra)
            }
            return first
        }
        let me = Person(name: "Mine", isMe: true, sortOrder: 0)
        context.insert(me)
        return me
    }

    /// What a new entry needs: one of Kath's accounts to pay from or receive into,
    /// and someone else's account (a payee or a person) on the other side.
    struct Readiness {
        let hasMyAccount: Bool
        let hasOtherAccount: Bool
        var isReady: Bool { hasMyAccount && hasOtherAccount }

        init(accounts: [Account]) {
            hasMyAccount = accounts.contains { $0.owner?.isMe == true }
            hasOtherAccount = accounts.contains { $0.owner != nil && $0.owner?.isMe != true }
        }
    }
}
