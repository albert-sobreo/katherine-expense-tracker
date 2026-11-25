import SwiftUI

/// Where the monthly budget lives. One limit that applies to every month.
enum Budget {
    static let key = "monthlyBudget"
}

/// Set or remove the monthly spending limit.
struct BudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @AppStorage(Budget.key) private var budget = 0
    @State private var text = ""
    @FocusState private var focused: Bool
    @State private var askDiscard = false

    private var centavos: Int {
        guard let d = Double(text.replacingOccurrences(of: ",", with: "")) else { return 0 }
        return Int((d * 100).rounded())
    }

    private var dirty: Bool { centavos != budget && !(text.isEmpty && budget == 0) }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Monthly budget").font(.outfit(20, .semibold))
                Spacer()
                Button { if dirty { askDiscard = true } else { dismiss() } } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(p.chip, in: .circle)
                }
                .buttonStyle(.plain)
            }
            Text("How much Kath plans to spend each month. Home shows how much is left.")
                .font(.outfit(14)).foregroundStyle(p.muted)

            HStack(spacing: 8) {
                Text("₱").font(.barlow(30, .medium)).foregroundStyle(p.muted)
                TextField("0", text: $text)
                    .font(.barlow(44))
                    .monospacedDigit()
                    .decimalPad()
                    .focused($focused)
                    .onChange(of: text) { _, new in
                        let clean = EntryView.sanitize(new)
                        if clean != new { text = clean }
                    }
            }
            .padding(.horizontal, 18)
            .frame(height: 76)
            .background(p.card, in: .rect(cornerRadius: 18))

            PrimaryButton(title: "Save", enabled: centavos > 0) {
                budget = centavos
                dismiss()
            }
            if budget > 0 {
                Button("Remove budget") {
                    budget = 0
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.outfit(14, .semibold))
                .foregroundStyle(Color(hex: scheme == .dark ? "#FB7185" : "#F43F5E"))
                .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 8)
        .foregroundStyle(p.fg)
        .background(p.bg)
        .presentationDetents([.medium])
        .onAppear {
            if budget > 0 { text = EntryView.sanitize(Money.number(budget)) }
            focused = true
        }
        .discardGuard(dirty: dirty, asking: $askDiscard) { dismiss() }
    }
}
