import SwiftUI

/// Account tile for Home: name top-left, "Credit •• 3456" under it, balance bottom-right.
struct BalanceTile: View {
    let account: Account

    var body: some View {
        let sub = account.isLoan ? account.loanStatus : [account.kind == .credit ? "Credit" : nil,
                   account.last4.isEmpty ? nil : "•• \(account.last4)"]
            .compactMap { $0 }.joined(separator: " ")
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(hex: account.colorHex))
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .center)
                        .clipShape(.rect(cornerRadius: 22))
                )
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.black.opacity(0.06), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(account.name)
                    .font(.outfit(13, .semibold))
                    .lineLimit(1)
                if !sub.isEmpty {
                    Text(sub)
                        .font(.barlow(13))
                        .opacity(0.75)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 11)
            Text(Money.short(account.balanceCentavos))
                .font(.barlow(19))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 11)
                .padding(.bottom, 8)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
        .frame(width: 88, height: 80)
        .scaleEffect(0.95)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(account.isLoan
            ? "\(account.name) loan, \(account.loanStatus.lowercased()) \(Money.number(abs(account.balanceCentavos))) pesos"
            : account.kind == .credit
            ? "\(account.name), owes \(Money.number(-account.balanceCentavos)) pesos"
            : "\(account.name), balance \(Money.number(account.balanceCentavos)) pesos")
    }
}
