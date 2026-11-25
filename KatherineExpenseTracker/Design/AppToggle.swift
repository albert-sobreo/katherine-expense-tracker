import SwiftUI

/// The app's switch: black and white like the rest of the UI. On is a filled track in the text color
/// with a knob in the background color; off is a quiet chip track. Readable in light and dark mode,
/// unlike a tinted system switch whose white knob vanishes on a white track.
struct AppToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        let p = Palette.of(scheme)
        let on = configuration.isOn
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: on ? .trailing : .leading) {
                    Capsule().fill(on ? p.fg : p.chip)
                        .overlay(Capsule().strokeBorder(p.line, lineWidth: on ? 0 : 1))
                    Circle().fill(on ? p.bg : p.muted)
                        .padding(3)
                        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
                }
                .frame(width: 50, height: 30)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(on ? "On" : "Off")
    }
}

extension ToggleStyle where Self == AppToggleStyle {
    static var app: AppToggleStyle { AppToggleStyle() }
}
