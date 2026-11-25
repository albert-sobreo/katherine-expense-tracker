import SwiftUI

/// A loan as a Home tile, same look as a balance tile: name, Owes you / You owe / Even, and the amount.
struct LoanLineTile: View {
    let line: LoanLine

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(hex: line.colorHex))
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .center)
                        .clipShape(.rect(cornerRadius: 22))
                )
                .overlay(RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(Color.black.opacity(Color.isLight(hex: line.colorHex) ? 0.12 : 0.06), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(line.name)
                    .font(.outfit(13, .semibold))
                    .lineLimit(1)
                Text(line.status)
                    .font(.barlow(13))
                    .opacity(0.75)
            }
            .padding(.top, 10)
            .padding(.horizontal, 11)
            Text(Money.short(line.balance))
                .font(.barlow(19))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 11)
                .padding(.bottom, 8)
        }
        .foregroundStyle(Color.tileText(hex: line.colorHex))
        .shadow(color: .black.opacity(Color.isLight(hex: line.colorHex) ? 0 : 0.22), radius: 1, y: 1)
        .frame(width: 88, height: 80)
        .scaleEffect(0.95)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(line.name) loan, \(line.status.lowercased()) \(Money.number(abs(line.balance))) pesos")
    }
}
