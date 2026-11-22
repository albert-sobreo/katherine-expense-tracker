import SwiftUI
import SwiftData

/// The one-screen entry: amount hero, Expense / Income / Transfer, two account rails, date wheel, Save & new.
/// Built to be as fast as typing a spreadsheet row: after saving, the amount clears and the selections stay.
struct EntryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    @State private var kind: EntryKind = .expense
    @State private var amountText = ""
    @State private var note = ""
    @State private var showNote = false
    @State private var fromID: PersistentIdentifier?
    @State private var toID: PersistentIdentifier?
    @State private var date = Date.now
    @State private var toast: String?
    @State private var showForm = false
    @FocusState private var amountFocused: Bool
    /// Width of the typed amount at full size, and the width the field has. Used to shrink the amount to fit.
    @State private var amountNaturalWidth: CGFloat = 0
    @State private var amountFieldWidth: CGFloat = 0

    private static let amountMaxSize: CGFloat = 100
    private static let amountMinSize: CGFloat = 40

    /// Like the Phone app: full size while it fits, then shrinks smoothly with the width, never below the minimum.
    private var amountSize: CGFloat {
        guard amountNaturalWidth > 0, amountFieldWidth > 0 else { return Self.amountMaxSize }
        let fit = Self.amountMaxSize * (amountFieldWidth - 8) / amountNaturalWidth
        return min(Self.amountMaxSize, max(Self.amountMinSize, fit))
    }

    private var groups: [RailGroup] { RailGroup.build(people: people, accounts: accounts) }

    /// Kath's own accounts, most-used first.
    private var mine: [Account] { groups.first { $0.label == "Mine" }?.accounts ?? [] }

    private var centavos: Int {
        guard let d = Double(amountText.replacingOccurrences(of: ",", with: "")) else { return 0 }
        return Int((d * 100).rounded())
    }

    private var canSave: Bool {
        guard centavos > 0 else { return false }
        switch kind {
        case .expense: return fromID != nil
        case .income: return toID != nil
        case .transfer: return fromID != nil && toID != nil && fromID != toID
        }
    }

    private var labels: (from: String, to: String) {
        switch kind {
        case .expense: ("Pay from", "Paid to")
        case .income: ("Received from", "Into")
        case .transfer: ("From", "To")
        }
    }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header(p)
                    hero
                    kindSwitch(p)
                    AccountRail(label: labels.from, groups: groups, selection: $fromID) { showForm = true }
                    AccountRail(label: labels.to, groups: groups, selection: $toID) { showForm = true }
                    dateCard(p)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)

            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 56, height: 56)
                        .background(p.chip, in: .rect(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
                PrimaryButton(title: "Save & new", enabled: canSave, action: save)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.outfit(13, .semibold))
                    .foregroundStyle(p.bg)
                    .padding(.horizontal, 16).frame(height: 40)
                    .background(p.fg, in: .capsule)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showForm) { AccountForm(owner: nil) }
        .onAppear {
            applyDefaults()
            amountFocused = true
        }
        .onChange(of: kind) { applyDefaults() }
    }

    // MARK: Pieces

    private func header(_ p: Palette) -> some View {
        HStack {
            Text("New entry").font(.outfit(17, .bold))
            Spacer()
            Text(date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.barlow(17, .medium))
                .foregroundStyle(p.muted)
        }
        .padding(.horizontal, 4)
        .frame(height: 40)
    }

    private var hero: some View {
        let dark = scheme == .dark
        let size = amountSize
        return VStack(spacing: 6) {
            Text(kind.rawValue.uppercased())
                .font(.outfit(11, .semibold))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Text("₱")
                    .font(.barlow(34, .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("", text: $amountText, prompt: Text("0").foregroundStyle(.white.opacity(0.28)))
                    .font(.barlow(size, .semibold))
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .tint(.white)
                    .lineLimit(1)
                    .decimalPad()
                    .focused($amountFocused)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { amountFieldWidth = $0 }
                    .background {
                        // Same text at full size, unconstrained, only to measure how wide it wants to be.
                        Text(amountText.isEmpty ? "0" : amountText)
                            .font(.barlow(Self.amountMaxSize, .semibold))
                            .monospacedDigit()
                            .fixedSize()
                            .hidden()
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { amountNaturalWidth = $0 }
                    }
                    .padding(.horizontal, 30)
                    .onChange(of: amountText) { _, new in
                        let clean = Self.sanitize(new)
                        if clean != new { amountText = clean }
                    }
                    .accessibilityLabel("Amount in pesos")
            }
            .frame(height: 110)
            .animation(.easeOut(duration: 0.1), value: size)

            if showNote {
                TextField("", text: $note, prompt: Text("Note").foregroundStyle(.white.opacity(0.4)))
                    .font(.outfit(14))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(.white.opacity(0.1), in: .capsule)
            } else {
                Button { withAnimation { showNote = true } } label: {
                    Label("Add note", systemImage: "text.bubble")
                        .font(.outfit(12, .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 14).frame(height: 30)
                        .background(.white.opacity(0.1), in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(minHeight: 196)
        .background {
            ZStack {
                Color(hex: "#18181B")
                RadialGradient(colors: [Color(hex: dark ? "#52525B" : "#71717A").opacity(0.55), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 260)
                RadialGradient(colors: [Color(hex: "#3F3F46").opacity(0.6), .clear],
                               center: .bottomLeading, startRadius: 0, endRadius: 220)
            }
            .clipShape(.rect(cornerRadius: 28))
        }
        .contentShape(.rect)
        .onTapGesture { amountFocused = true }
    }

    private func kindSwitch(_ p: Palette) -> some View {
        HStack(spacing: 4) {
            ForEach(EntryKind.allCases, id: \.self) { k in
                let on = k == kind
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { kind = k }
                } label: {
                    Text(k.rawValue.capitalized)
                        .font(.outfit(14, on ? .semibold : .medium))
                        .foregroundStyle(on ? p.fg : p.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(p.card)
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(p.chip, in: .rect(cornerRadius: 16))
    }

    private func dateCard(_ p: Palette) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Date")
                Spacer()
                Button(isToday ? "Today" : "Back to today") {
                    withAnimation { date = .now }
                }
                .buttonStyle(.plain)
                .font(.outfit(12, .semibold))
                .foregroundStyle(isToday ? p.muted : p.fg)
                .disabled(isToday)
            }
            .padding(.horizontal, 4)

            #if os(iOS)
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 108)
                .clipped()
                .background(p.card, in: .rect(cornerRadius: 22))
            #else
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .labelsHidden()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(p.card, in: .rect(cornerRadius: 22))
            #endif
        }
    }

    // MARK: Logic

    /// Keeps digits, one dot, and at most two decimals.
    static func sanitize(_ s: String) -> String {
        var out = ""
        var seenDot = false
        var decimals = 0
        for ch in s {
            if ch.isASCII, ch.isNumber {
                if seenDot {
                    guard decimals < 2 else { continue }
                    decimals += 1
                }
                if !seenDot, out == "0" { out = "" }
                out.append(ch)
            } else if ch == "." && !seenDot {
                seenDot = true
                if out.isEmpty { out = "0" }
                out.append(ch)
            }
        }
        return String(out.prefix(12))
    }

    private func applyDefaults() {
        let ids = mine.map(\.persistentModelID)
        switch kind {
        case .expense:
            fromID = ids.first
            toID = nil
        case .income:
            fromID = nil
            toID = ids.first
        case .transfer:
            fromID = ids.first
            toID = ids.count > 1 ? ids[1] : nil
        }
    }

    private func account(_ id: PersistentIdentifier?) -> Account? {
        guard let id else { return nil }
        return accounts.first { $0.persistentModelID == id }
    }

    private func save() {
        guard canSave else { return }
        let amount = centavos
        let entry = Entry(amountCentavos: amount, kind: kind, date: date,
                          from: account(fromID), to: account(toID),
                          note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(entry)
        try? context.save()

        let peso = (Double(amount) / 100).formatted(.number.precision(.fractionLength(2)))
        withAnimation(.spring(response: 0.35)) { toast = "Saved ₱\(peso) · ready for the next one" }
        amountText = ""
        note = ""
        showNote = false
        amountFocused = true
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut) { toast = nil }
        }
    }
}

#Preview {
    EntryView()
        .modelContainer(for: [Person.self, Account.self, Entry.self], inMemory: true)
}
