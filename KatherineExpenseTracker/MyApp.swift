import SwiftUI
import SwiftData

@main struct MyApp: App {
    /// Shared with Siri and Shortcuts (Intents/AppData.swift).
    let container: ModelContainer = AppData.container

    init() {
        FontRegistry.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
