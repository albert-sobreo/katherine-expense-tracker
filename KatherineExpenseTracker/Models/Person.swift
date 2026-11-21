import Foundation
import SwiftData

/// Whose money an account holds: Kath herself ("Mine"), or someone she manages
/// accounts for (Mama, Albert, ...). Payees like Meralco live under an "Others" person.
///
/// CloudKit sync rules: every property has a default, relationships are optional,
/// and nothing is marked unique.
@Model
final class Person {
    var name: String = ""
    /// True only for Kath's own group, shown as "Mine".
    var isMe: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Account.owner)
    var accounts: [Account]? = []

    init(name: String, isMe: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.isMe = isMe
        self.sortOrder = sortOrder
    }
}
