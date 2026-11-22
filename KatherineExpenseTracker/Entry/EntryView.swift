import SwiftUI
import SwiftData

/// The one-screen entry: amount hero, Expense / Income / Transfer, two account rails, date wheel, Save & new.
/// Built to be as fast as typing a spreadsheet row: after saving, the amount clears and the selections stay.
struct EntryView: View {
    /// The entry to edit. Nil logs new ones with Save & new.
    var editing: Entry? = nil
    /// An earlier entry to repeat: same type, amount, accounts and note, dated today, saved as a new entry.
    var template: Entry? = nil

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
    @State private var formChoice: AccountSetupPage.OwnerChoice?
    @FocusState private var amountFocused: Bool
    @State private var skipDefaults = false
    @State private var savedCount = 0
    /// Last accounts used per entry type, so the next entry starts where the last one left off.
    @AppStorage("lastAccounts") private var lastAccountsJSON = ""
    @State private var confirmDelete = false
    @State private var showWheel = false
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
    /// Payees, then loans, then accounts. Picking a loan here turns the entry into a Transfer.
    private var groupsWithPayees: [RailGroup] {
        RailGroup.build(people: people, accounts: accounts, withPayees: true, withLoans: true)
    }

    /// Payees show only where money leaves to them (Paid to) or comes from them (Received from).
    /// Loans show only on Transfer: lending, borrowing and paybacks are transfers to or from a loan tile.
    private var groupsWithLoans: [RailGroup] { RailGroup.build(people: people, accounts: accounts, withLoans: true) }

    private var fromGroups: [RailGroup] {
        switch kind {
        case .income: groupsWithPayees.filter { $0.label != "Mine" }
        case .transfer: groupsWithLoans
        case .expense: groups
        }
    }
    /// Paid to never lists Kath's own accounts: paying yourself is a transfer, not an expense.
    private var toGroups: [RailGroup] {
        switch kind {
        case .expense: groupsWithPayees.filter { $0.label != "Mine" }
        case .transfer: groupsWithLoans
        case .income: groups
        }
    }

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
                    AccountRail(label: labels.from, groups: fromGroups, selection: $fromID) {
                        formChoice = .init(person: nil, payee: kind == .income)
                    }
                    AccountRail(label: labels.to, groups: toGroups, selection: $toID) {
                        formChoice = .init(person: nil, payee: kind == .expense)
                    }
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
                PrimaryButton(title: editing == nil ? "Save & new" : "Save", enabled: canSave, action: save)
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
        .sheet(item: $formChoice) { choice in AccountForm(owner: choice.person, payee: choice.payee) }
        .onAppear {
            if let editing {
                load(editing)
            } else if let template {
                load(template)
                date = .now
                amountFocused = true
            } else {
                applyDefaults()
                amountFocused = true
            }
        }
        .sensoryFeedback(.success, trigger: savedCount)
        .onChange(of: toID) { _, id in
            // Lending to someone from Expense: loans move money, they aren't spending.
            if kind == .expense, account(id)?.isLoan == true { switchToTransfer() }
        }
        .onChange(of: fromID) { _, id in
            // Borrowing or a payback from Income: same, it's a Transfer.
            if kind == .income, account(id)?.isLoan == true { switchToTransfer() }
        }
        .onChange(of: kind) {
            if skipDefaults {
                skipDefaults = false
                return
            }
            applyDefaults()
        }
        .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let editing { context.delete(editing) }
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Balances update right away.")
        }
    }

    // MARK: Pieces

    private func header(_ p: Palette) -> some View {
        HStack {
            Text(editing == nil ? "New entry" : "Edit entry").font(.outfit(17, .bold))
            Spacer()
            if editing != nil {
                Button { confirmDelete = true } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#DC2626"))
                        .frame(width: 36, height: 36)
                        .background(p.chip, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete entry")
                .padding(.trailing, 6)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.outfit(13, .semibold))
                    .tracking(1)
                Text(date.formatted(.dateTime.day()))
                    .font(.barlow(17, .medium))
            }
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
                Color(hex: "#1D161E")
                RadialGradient(colors: [Color(hex: dark ? "#594C5B" : "#79697B").opacity(0.55), .clear],
                               center: .topTrailing, startRadius: 0, endRadius: 260)
                RadialGradient(colors: [Color(hex: "#463947").opacity(0.6), .clear],
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

    /// Today / Yesterday / a picked date as chips. The wheel opens only for other days.
    private func dateCard(_ p: Palette) -> some View {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(date)
        let isYesterday = cal.isDateInYesterday(date)
        let other = !isToday && !isYesterday
        return VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Date").padding(.horizontal, 4)
            HStack(spacing: 8) {
                dateChip("Today", on: isToday, p) {
                    date = .now
                    showWheel = false
                }
                dateChip("Yesterday", on: isYesterday, p) {
                    date = cal.date(byAdding: .day, value: -1, to: .now) ?? .now
                    showWheel = false
                }
                dateChip(other ? date.formatted(.dateTime.month(.abbreviated).day().year()) : "Pick date",
                         on: other || showWheel, p, icon: "calendar") {
                    withAnimation(.easeOut(duration: 0.2)) { showWheel.toggle() }
                }
            }
            if showWheel {
                #if os(iOS)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .clipped()
                    .background(p.card, in: .rect(cornerRadius: 22))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                #else
                DatePicker("Date", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(p.card, in: .rect(cornerRadius: 22))
                #endif
            }
        }
    }

    private func dateChip(_ title: String, on: Bool, _ p: Palette, icon: String? = nil,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.outfit(14, .semibold)).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .foregroundStyle(on ? p.bg : p.fg)
            .background(on ? p.fg : p.card, in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Logic

    /// Keeps digits, one dot, and at most two decimals, with commas every three digits: "12,500.75".
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
        let parts = out.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let whole = String(parts.first ?? "").prefix(9)
        var grouped = ""
        for (i, ch) in whole.enumerated() {
            if i > 0 && (whole.count - i) % 3 == 0 { grouped.append(",") }
            grouped.append(ch)
        }
        return parts.count > 1 ? grouped + "." + String(parts[1]) : grouped
    }

    private struct LastPair: Codable {
        var from: PersistentIdentifier?
        var to: PersistentIdentifier?
    }

    private var lastAccounts: [String: LastPair] {
        guard let data = lastAccountsJSON.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: LastPair].self, from: data)) ?? [:]
    }

    private func rememberAccounts() {
        var all = lastAccounts
        all[kind.rawValue] = LastPair(from: fromID, to: toID)
        if let data = try? JSONEncoder().encode(all), let text = String(data: data, encoding: .utf8) {
            lastAccountsJSON = text
        }
    }

    private func applyDefaults() {
        // Start from the accounts used last time for this type, when they still exist and are allowed here.
        if let last = lastAccounts[kind.rawValue] {
            let fromOK = last.from.map { id in fromGroups.contains { $0.accounts.contains { $0.persistentModelID == id } } } ?? false
            let toOK = last.to.map { id in toGroups.contains { $0.accounts.contains { $0.persistentModelID == id } } } ?? false
            if fromOK || toOK {
                fromID = fromOK ? last.from : nil
                toID = toOK ? last.to : nil
                if kind == .transfer, fromID == toID { toID = nil }
                if (kind == .income ? toID != nil : fromID != nil) { return }
            }
        }
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

    /// Keeps both picks and flips the type to Transfer, with a short note why.
    private func switchToTransfer() {
        if kind == .expense, fromID == nil { fromID = mine.first?.persistentModelID }
        if kind == .income, toID == nil { toID = mine.first?.persistentModelID }
        skipDefaults = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            kind = .transfer
            toast = "Loans are Transfers, switched for you"
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut) { if toast == "Loans are Transfers, switched for you" { toast = nil } }
        }
    }

    private func account(_ id: PersistentIdentifier?) -> Account? {
        guard let id else { return nil }
        return accounts.first { $0.persistentModelID == id }
    }

    /// Fills the screen from the entry being edited.
    private func load(_ e: Entry) {
        if e.kind != kind {
            skipDefaults = true
            kind = e.kind
        }
        let c = e.amountCentavos
        amountText = Self.sanitize(c % 100 == 0 ? String(c / 100) : String(format: "%.2f", Double(c) / 100))
        note = e.note
        showNote = !e.note.isEmpty
        fromID = e.from?.persistentModelID
        toID = e.to?.persistentModelID
        date = e.date
    }

    private func save() {
        guard canSave else { return }
        if let editing {
            editing.amountCentavos = centavos
            editing.kind = kind
            editing.date = date
            editing.from = account(fromID)
            editing.to = account(toID)
            editing.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            try? context.save()
            dismiss()
            return
        }
        let amount = centavos
        rememberAccounts()
        savedCount += 1
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
