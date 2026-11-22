import SwiftUI
import SwiftData

/// Shows onboarding on first launch, then Home.
struct ContentView: View {
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if didFinishOnboarding {
                HomeView()
            } else {
                OnboardingFlow { withAnimation { didFinishOnboarding = true } }
            }
        }
        .task { Setup.me(in: context) }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
