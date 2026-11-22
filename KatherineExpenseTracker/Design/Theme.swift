import SwiftUI

/// Tailwind mauve palette (a gray with a soft purple tint), light and dark.
struct Palette {
    let bg: Color
    let card: Color
    let fg: Color
    let muted: Color
    let chip: Color
    let line: Color

    static func of(_ scheme: ColorScheme) -> Palette {
        scheme == .dark
            // mauve-950 bg, -900 card, -50 text, -400 muted, -800 chip, -700 line
            ? Palette(bg: Color(hex: "#0C090C"), card: Color(hex: "#1D161E"), fg: Color(hex: "#FAFAFA"),
                      muted: Color(hex: "#A89EA9"), chip: Color(hex: "#2A212C"), line: Color(hex: "#463947"))
            // mauve-100 bg, white card, -950 text, -500 muted, -200 chip, -300 line
            : Palette(bg: Color(hex: "#F3F1F3"), card: Color(hex: "#FFFFFF"), fg: Color(hex: "#0C090C"),
                      muted: Color(hex: "#79697B"), chip: Color(hex: "#E7E4E7"), line: Color(hex: "#D7D0D7"))
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0x3F3F46
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: 1)
    }
}

extension Font {
    /// Outfit for all text. One variable font file, so any weight works.
    static func outfit(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom("Outfit", size: size).weight(weight)
    }

    /// Barlow Condensed for all numbers. Bundled in Medium, SemiBold and Bold.
    static func barlow(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "BarlowCondensed-Bold"
        case .semibold: name = "BarlowCondensed-SemiBold"
        default: name = "BarlowCondensed-Medium"
        }
        return .custom(name, size: size)
    }
}

/// The small uppercase, tracked label used above every section.
struct SectionLabel: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.outfit(11, .semibold))
            .tracking(1.8)
            .foregroundStyle(Palette.of(scheme).muted)
    }
}

/// Full-width dark (light in dark mode) button, like Save & new.
struct PrimaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = Palette.of(scheme)
        Button(action: action) {
            Text(title.uppercased())
                .font(.outfit(13, .semibold))
                .tracking(2)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(p.bg)
                .background(p.fg, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }
}

extension View {
    /// Decimal pad on iPhone; ignored on Mac.
    func decimalPad() -> some View {
        #if os(iOS)
        return self.keyboardType(.decimalPad)
        #else
        return self
        #endif
    }

    /// Number pad on iPhone; ignored on Mac.
    func numberPad() -> some View {
        #if os(iOS)
        return self.keyboardType(.numberPad)
        #else
        return self
        #endif
    }
}
