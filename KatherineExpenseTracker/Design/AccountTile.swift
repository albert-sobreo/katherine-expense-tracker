import SwiftUI

/// The brand-color square used everywhere for accounts: name top-left, "•• 1234" bottom-right.
/// Selected tiles lift with a glow in their own color and a thin soft-white inner border.
struct AccountTile: View {
    let name: String
    let last4: String
    let colorHex: String
    var selected = false
    var width: CGFloat = 88
    var height: CGFloat = 80

    var body: some View {
        let color = Color(hex: colorHex)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(color)
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .center)
                        .clipShape(.rect(cornerRadius: 22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(selected ? Color.white.opacity(0.65) : Color.black.opacity(0.06), lineWidth: selected ? 2 : 1)
                )
            Text(name)
                .font(.outfit(13, .semibold))
                .lineLimit(2)
                .padding(.top, 10)
                .padding(.horizontal, 11)
            if !last4.isEmpty {
                Text("•• \(last4)")
                    .font(.barlow(18))
                    .monospacedDigit()
                    .opacity(0.92)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 11)
                    .padding(.bottom, 8)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
        .frame(width: width, height: height)
        .shadow(color: selected ? color.opacity(0.55) : .clear, radius: 12, y: 10)
        .scaleEffect(selected ? 1 : 0.95)
        .offset(y: selected ? -3 : 0)
        .animation(.easeOut(duration: 0.16), value: selected)
    }
}

#Preview {
    HStack(spacing: 0) {
        AccountTile(name: "GCash", last4: "4821", colorHex: "#007DFE", selected: true)
        AccountTile(name: "BDO", last4: "1234", colorHex: "#0033A0")
        AccountTile(name: "Cash", last4: "", colorHex: "#3F3F46")
    }
    .padding()
}
