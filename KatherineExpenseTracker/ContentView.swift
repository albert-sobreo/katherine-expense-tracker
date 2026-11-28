import SwiftUI
import SwiftData
import AppIntents

/// Shows onboarding on first launch, then Home.
struct ContentView: View {
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    @Environment(\.modelContext) private var context
    /// An expense another app (DueDay) asked to log through a katherine:// link.
    @State private var logRequest: LogRequest?
    /// The "New Entry" shortcut asked for the entry screen.
    @State private var showNewEntry = false
    @Query private var accounts: [Account]
    private let router = IntentRouter.shared

    var body: some View {
        Group {
            if didFinishOnboarding {
                AdaptiveRoot()
            } else {
                OnboardingFlow { withAnimation { didFinishOnboarding = true } }
            }
        }
        // Default for any text that doesn't set its own font, including system controls.
        .font(.outfit(17))
        // Borderless text fields everywhere. iOS already draws them this way; on the Mac the default is a
        // bordered box with a blue focus ring, which broke the big amount field.
        .textFieldStyle(.plain)
        #if os(macOS)
        .focusEffectDisabled()
        #endif
        .task { Setup.me(in: context) }
        .onOpenURL { url in
            guard didFinishOnboarding, let request = LogRequest(url: url) else { return }
            logRequest = request
        }
        // Siri phrases that name an account ("Log a GCash expense in Kuarta") need the current names.
        .task(id: accounts.map(\.name).joined(separator: "|")) {
            KuartaShortcuts.updateAppShortcutParameters()
        }
        .onChange(of: router.wantsNewEntry, initial: true) { _, wants in
            guard wants else { return }
            router.wantsNewEntry = false
            if didFinishOnboarding && logRequest == nil { showNewEntry = true }
        }
        .sheet(isPresented: $showNewEntry) {
            #if os(macOS)
            EntryView().frame(minWidth: 420, minHeight: 760)
            #else
            EntryView()
            #endif
        }
        .sheet(item: $logRequest) { request in
            #if os(macOS)
            EntryView(request: request).frame(minWidth: 420, minHeight: 760)
            #else
            EntryView(request: request)
            #endif
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
