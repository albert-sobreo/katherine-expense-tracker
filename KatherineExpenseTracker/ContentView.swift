import SwiftUI
import SwiftData

/// Shows onboarding on first launch, then Home.
struct ContentView: View {
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    @Environment(\.modelContext) private var context

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
        .task { Setup.me(in: context) }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
