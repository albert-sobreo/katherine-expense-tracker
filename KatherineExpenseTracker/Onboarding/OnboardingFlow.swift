import SwiftUI

/// First launch: one welcome page, then account and person setup. Both can be skipped.
struct OnboardingFlow: View {
    var onFinish: () -> Void
    @State private var step = 0

    var body: some View {
        Group {
            if step == 0 {
                WelcomePage(onStart: { withAnimation { step = 1 } }, onSkip: onFinish)
                    .transition(.move(edge: .leading))
            } else {
                AccountSetupPage(isOnboarding: true, onDone: onFinish)
                    .transition(.move(edge: .trailing))
            }
        }
    }
}

struct WelcomePage: View {
    var onStart: () -> Void
    var onSkip: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onSkip)
                    .buttonStyle(.plain)
                    .font(.outfit(15, .semibold))
                    .foregroundStyle(p.muted)
                    .frame(height: 44)
            }
            .padding(.horizontal, 20)

            Spacer()

            ZStack {
                AccountTile(name: "BDO", last4: "1234", colorHex: "#0033A0", width: 132, height: 120)
                    .rotationEffect(.degrees(-10)).offset(x: -78, y: 14)
                AccountTile(name: "Maya", last4: "1150", colorHex: "#00D26A", width: 132, height: 120)
                    .rotationEffect(.degrees(9)).offset(x: 78, y: 18)
                AccountTile(name: "GCash", last4: "4821", colorHex: "#007DFE", selected: true, width: 140, height: 128)
            }
            .frame(height: 190)
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Every peso,\none row.")
                    .font(.outfit(36, .bold))
                    .multilineTextAlignment(.center)
                Text("Log spending as fast as your spreadsheet. Your accounts, and the ones you handle for others, in one place.")
                    .font(.outfit(16))
                    .foregroundStyle(p.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .padding(.top, 36)

            Spacer()

            PrimaryButton(title: "Get started", action: onStart)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
    }
}

#Preview {
    OnboardingFlow(onFinish: {})
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
