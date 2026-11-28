import Foundation
import SwiftData
import Observation

/// The one data store, shared by the app's windows and by Siri and Shortcuts. Their actions run
/// inside the app, so an entry Siri logs shows up at once if the app is open.
/// Stored on device and synced through the iCloud container in KatherineExpenseTracker.entitlements.
@MainActor
enum AppData {
    static let container: ModelContainer = {
        let schema = Schema([Person.self, Account.self, Entry.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
    }()
}

/// Lets the "New Entry" shortcut open the entry screen. ContentView watches it.
@MainActor @Observable
final class IntentRouter {
    static let shared = IntentRouter()
    var wantsNewEntry = false
}
