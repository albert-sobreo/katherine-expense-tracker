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

    /// What a new entry needs: one of Kath's own accounts. Other people's accounts and
    /// payees are optional and can be added any time.
    struct Readiness {
        let hasMyAccount: Bool
        var isReady: Bool { hasMyAccount }

        init(accounts: [Account]) {
            hasMyAccount = accounts.contains { $0.owner?.isMe == true }
        }
    }
}
