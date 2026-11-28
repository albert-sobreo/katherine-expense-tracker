import Foundation
import AppIntents

/// A bank, e-wallet, card or loan, as Siri and Shortcuts see it. Yours first, then other people's.
nonisolated struct AccountEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Account" }
    static var defaultQuery: AccountQuery { AccountQuery() }

    let id: String
    let name: String
    /// "Mine · •• 1234", "Mama", "Loan".
    let detail: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)",
                              subtitle: detail.isEmpty ? nil : LocalizedStringResource(stringLiteral: detail))
    }

    @MainActor init(_ a: Account) {
        id = IntentStore.key(a)
        name = a.name
        var parts: [String] = []
        if a.isLoan {
            parts.append("Loan")
        } else {
            parts.append(a.owner?.isMe == true ? "Mine" : (a.owner?.name ?? "Others"))
            if a.kind == .credit { parts.append("Card") }
            if !a.last4.isEmpty { parts.append("•• \(a.last4)") }
        }
        detail = parts.joined(separator: " · ")
    }
}

nonisolated struct AccountQuery: EntityStringQuery {
    init() {}

    @MainActor func entities(for identifiers: [String]) async throws -> [AccountEntity] {
        let all = IntentStore.holdings()
        return identifiers.compactMap { id in all.first { IntentStore.key($0) == id } }.map { AccountEntity($0) }
    }

    @MainActor func entities(matching string: String) async throws -> [AccountEntity] {
        IntentStore.search(IntentStore.holdings(), string).map { AccountEntity($0) }
    }

    @MainActor func suggestedEntities() async throws -> [AccountEntity] {
        IntentStore.holdings().map { AccountEntity($0) }
    }
}

/// Someone or something money goes to or comes from: Meralco, Grab, a store, salary.
nonisolated struct PayeeEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Payee" }
    static var defaultQuery: PayeeQuery { PayeeQuery() }

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    @MainActor init(_ a: Account) {
        id = IntentStore.key(a)
        name = a.name
    }
}

nonisolated struct PayeeQuery: EntityStringQuery {
    init() {}

    @MainActor func entities(for identifiers: [String]) async throws -> [PayeeEntity] {
        let all = IntentStore.payees()
        return identifiers.compactMap { id in all.first { IntentStore.key($0) == id } }.map { PayeeEntity($0) }
    }

    @MainActor func entities(matching string: String) async throws -> [PayeeEntity] {
        IntentStore.search(IntentStore.payees(), string).map { PayeeEntity($0) }
    }

    @MainActor func suggestedEntities() async throws -> [PayeeEntity] {
        IntentStore.payees().map { PayeeEntity($0) }
    }
}
