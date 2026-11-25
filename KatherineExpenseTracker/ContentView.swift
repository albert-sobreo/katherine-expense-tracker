import SwiftUI
import SwiftData

/// Shows onboarding on first launch, then Home.
struct ContentView: View {
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    @Environment(\.modelContext) private var context
    /// An expense another app (DueDay) asked to log through a katherine:// link.
    @State private var logRequest: LogRequest?

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
