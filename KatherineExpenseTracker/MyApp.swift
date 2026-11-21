import SwiftUI
import SwiftData

@main struct MyApp: App {
    /// Stored on device and synced through the iCloud container in
    /// KatherineExpenseTracker.entitlements.
    let container: ModelContainer = {
        let schema = Schema([Person.self, Account.self, Entry.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not create the data store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
