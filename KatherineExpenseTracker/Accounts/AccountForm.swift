import SwiftUI
import SwiftData

/// "New account": Bank or wallet vs Payee at the top. Bank or wallet: whose account, Debit or Credit,
/// name, last 4, and a preset that fills in the name and color. "+ Person" opens the New person sheet.
/// Payee (Meralco, Grab, a store, salary): just a name and color, no owner or balance.
struct AccountForm: View {
    /// Pre-selected owner, e.g. Kath's own group. Nil makes the person pick.
    var owner: Person?
    /// Start on Payee instead of Bank or wallet.
    var payee = false
    /// Start on Loan.
    var loan = false
    /// The account to edit. Nil adds a new one.
    var editing: Account? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @Query private var accounts: [Account]

    @State private var selectedOwner: Person?
    @State private var kind: AccountKind = .debit
    @State private var name = ""
    @State private var last4 = ""
    @State private var colorHex = BankPreset.all[0].hex
    @State private var pickedPreset: BankPreset?
    @State private var limit = ""
    @State private var opening = ""
    @State private var dueDay = ""
    @State private var showPersonSheet = false
    @State private var type: AccountType = .bank
    /// Loans: true when the starting balance is what they owe Kath, false when Kath owes them.
    @State private var theyOwe = true
    @State private var skipTypeReset = false
    @State private var confirmDelete = false
    @State private var askDiscard = false
    /// The form as it opened, to tell whether anything changed.
    @State private var baseline: String?

    enum AccountType: CaseIterable { case bank, payee, loan }
    private var isPayee: Bool { type == .payee }
    private var isLoan: Bool { type == .loan }

    private var presets: [BankPreset] {
        switch type {
        case .bank: BankPreset.all
        case .payee: BankPreset.payees
        case .loan: BankPreset.loanColors + BankPreset.cardColors.filter { c in !BankPreset.loanColors.contains { $0.hex == c.hex } }
        }
    }


    private var fingerprint: String {
        [String(describing: type), String(describing: kind), selectedOwner?.name ?? "", name, last4,
         colorHex, limit, opening, dueDay, String(theyOwe)].joined(separator: "|")
    }
    private var dirty: Bool { baseline != nil && fingerprint != baseline }

    private var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        return type == .bank ? (selectedOwner != nil && hasName) : hasName
    }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            header(p)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if editing == nil { typeSwitch(p) }
                    if type == .bank {
                        ownerRow(p)
                        kindSwitch(p)
                    }
                    if isLoan { directionSwitch(p) }
                    nameRow(p)
                    if !isPayee { openingRow(p) }
                    if type == .bank && kind == .credit { creditRow(p) }
                    if isLoan {
                        Text("Lending, borrowing and paybacks are Transfers to or from this tile. Above zero they owe you; below zero you owe them.")
                            .font(.outfit(13)).foregroundStyle(p.muted)
                            .padding(.horizontal, 4)
                    }
                    presetGrid(p)
                    if !isLoan { colorGrid(p) }
                    if editing != nil { deleteButton(p) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .onAppear {
            defer { baseline = fingerprint }
            if let editing {
                load(editing)
                return
            }
            if selectedOwner == nil { selectedOwner = owner }
            if payee {
                skipTypeReset = true
                type = .payee
                colorHex = BankPreset.payees[0].hex
            } else if loan {
                skipTypeReset = true
                type = .loan
                colorHex = BankPreset.loanColors[0].hex
            }
        }
        .onChange(of: type) { _, _ in
            if skipTypeReset {
                skipTypeReset = false
                return
            }
            // Switching type clears a preset name from the other list, but keeps a name she typed.
            if pickedPreset != nil || name.isEmpty { name = "" }
            pickedPreset = nil
            colorHex = presets[0].hex
        }
        .discardGuard(dirty: dirty, asking: $askDiscard) { dismiss() }
        .sheet(isPresented: $showPersonSheet) {
            PersonSheet { selectedOwner = $0 }
        }
    }

    // MARK: Sections

    private func header(_ p: Palette) -> some View {
        HStack {
            Button("Cancel") { if dirty { askDiscard = true } else { dismiss() } }
                .buttonStyle(.plain)
                .font(.outfit(15, .semibold))
                .padding(.horizontal, 14).frame(height: 34)
                .background(p.chip, in: .capsule)
            Spacer()
            Text(title).font(.outfit(17, .bold))
            Spacer()
            Button("Save", action: save)
                .buttonStyle(.plain)
                .font(.outfit(15, .bold))
                .foregroundStyle(p.bg)
                .padding(.horizontal, 14).frame(height: 34)
                .background(p.fg, in: .capsule)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.35)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var title: String {
        switch type {
        case .payee: return editing == nil ? "New payee" : "Edit payee"
        case .loan: return editing == nil ? "New loan" : "Edit loan"
        case .bank: return editing == nil ? "New account" : "Edit account"
        }
    }

    private func deleteButton(_ p: Palette) -> some View {
        Button { confirmDelete = true } label: {
            Text(isPayee ? "Delete payee" : (isLoan ? "Delete loan" : "Delete account"))
                .font(.outfit(13, .semibold)).tracking(1.6).textCase(.uppercase)
                .foregroundStyle(Color(hex: "#DC2626"))
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(p.chip, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .confirmationDialog("Delete \(editing?.name ?? "this")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let editing { context.delete(editing) }
                dismiss()
            }
        } message: {
            Text("Its entries stay, but they won't show this account anymore.")
        }
    }

    private func typeSwitch(_ p: Palette) -> some View {
        HStack(spacing: 3) {
            ForEach(AccountType.allCases, id: \.self) { option in
                let on = type == option
                Button { type = option } label: {
                    VStack(spacing: 1) {
                        Text(option == .bank ? "BANK" : (option == .payee ? "PAYEE" : "LOAN"))
                            .font(.outfit(12, .semibold)).tracking(1.4)
                        Text(option == .bank ? "Money kept" : (option == .payee ? "Bills, stores" : "Lent, borrowed"))
                            .font(.outfit(11, .medium)).foregroundStyle(p.muted)
                    }
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .foregroundStyle(on ? p.fg : p.muted)
                    .background(on ? p.card : .clear, in: .rect(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(p.chip, in: .rect(cornerRadius: 14))
    }

    private func ownerRow(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Whose account").padding(.horizontal, 4)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Button { showPersonSheet = true } label: {
                        Label("Person", systemImage: "plus")
                            .font(.outfit(12, .semibold))
                            .tracking(1.4)
                            .textCase(.uppercase)
                            .padding(.horizontal, 14).frame(height: 36)
                            .overlay(Capsule().strokeBorder(p.muted, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
                    }
                    .buttonStyle(.plain)
                    ForEach(people) { person in
                        let on = selectedOwner?.persistentModelID == person.persistentModelID
                        Button { selectedOwner = person } label: {
                            Text(person.name.uppercased())
                                .font(.outfit(12, .semibold))
                                .tracking(1.4)
                                .padding(.horizontal, 16).frame(height: 36)
                                .foregroundStyle(on ? p.bg : p.fg)
                                .background(on ? p.fg : p.chip, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .padding(.horizontal, -16)
        }
    }

    private func kindSwitch(_ p: Palette) -> some View {
        HStack(spacing: 3) {
            ForEach(AccountKind.allCases, id: \.self) { option in
                let on = kind == option
                Button { kind = option } label: {
                    VStack(spacing: 1) {
                        Text(option == .debit ? "DEBIT" : "CREDIT")
                            .font(.outfit(12, .semibold)).tracking(1.4)
                        Text(option == .debit ? "Money you have" : "Money you owe")
                            .font(.outfit(11, .medium)).foregroundStyle(p.muted)
                    }
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .foregroundStyle(on ? p.fg : p.muted)
                    .background(on ? p.card : .clear, in: .rect(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(p.chip, in: .rect(cornerRadius: 14))
    }

    /// Loans: whether the starting balance is owed to Kath or by her.
    private func directionSwitch(_ p: Palette) -> some View {
        HStack(spacing: 3) {
            ForEach([true, false], id: \.self) { option in
                let on = theyOwe == option
                Button { theyOwe = option } label: {
                    VStack(spacing: 1) {
                        Text(option ? "THEY OWE ME" : "I OWE THEM")
                            .font(.outfit(12, .semibold)).tracking(1.4)
                        Text("Starting balance")
                            .font(.outfit(11, .medium)).foregroundStyle(p.muted)
                    }
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .foregroundStyle(on ? p.fg : p.muted)
                    .background(on ? p.card : .clear, in: .rect(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(p.chip, in: .rect(cornerRadius: 14))
    }

    /// The typed starting amount, signed: negative for a card or for money Kath owes on a loan.
    private var signedOpening: Int {
        let typed = Double(opening.replacingOccurrences(of: ",", with: "")).map { Int(($0 * 100).rounded()) } ?? 0
        if isLoan { return theyOwe ? typed : -typed }
        return kind == .credit ? -typed : typed
    }

    /// Balance the preview tile shows: the typed starting balance plus any entries already logged.
    private var previewBalance: Int {
        let activity = editing.map { $0.balanceCentavos - $0.openingCentavos } ?? 0
        return signedOpening + activity
    }

    private var previewLoanStatus: String? {
        guard isLoan else { return nil }
        let b = previewBalance
        return b > 0 ? "Owes you" : (b < 0 ? "You owe" : "Even")
    }

    private func nameRow(_ p: Palette) -> some View {
        HStack(spacing: 12) {
            AccountTile(name: name.isEmpty ? "Name" : name, last4: type == .bank ? last4 : "", colorHex: colorHex,
                        selected: true, width: 110, height: 100,
                        balance: isPayee ? nil : previewBalance, isCredit: type == .bank && kind == .credit,
                        loanStatus: previewLoanStatus)
            VStack(spacing: 0) {
                HStack {
                    Text("Name").font(.outfit(14, .medium))
                    TextField(isPayee ? "Meralco" : (isLoan ? "Mama" : "BDO Savings"), text: $name)
                        .font(.outfit(15, .semibold))
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxHeight: .infinity)
                if type == .bank {
                    Divider().overlay(p.line)
                    HStack {
                        Text("Last 4").font(.outfit(14, .medium))
                        TextField("Optional", text: $last4)
                            .font(.barlow(19))
                            .multilineTextAlignment(.trailing)
                            .numberPad()
                            .onChange(of: last4) { _, new in
                                let digits = String(new.filter(\.isNumber).prefix(4))
                                if digits != new { last4 = digits }
                            }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 100)
            .background(p.card, in: .rect(cornerRadius: 18))
        }
    }

    /// What's in the account right now (or owed, for a card), so balances start from the real number.
    private func openingRow(_ p: Palette) -> some View {
        HStack {
            Text(isLoan ? "Amount now" : (kind == .credit ? "Owed now" : "Balance now")).font(.outfit(14, .medium))
            TextField("₱0", text: $opening)
                .font(.barlow(19))
                .multilineTextAlignment(.trailing)
                .decimalPad()
                .onChange(of: opening) { _, new in
                    let clean = EntryView.sanitize(new)
                    if clean != new { opening = clean }
                }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(p.card, in: .rect(cornerRadius: 18))
    }

    private func creditRow(_ p: Palette) -> some View {
        HStack(spacing: 0) {
            HStack {
                Text("Limit").font(.outfit(14, .medium))
                TextField("₱0", text: $limit)
                    .font(.barlow(19))
                    .multilineTextAlignment(.trailing)
                    .numberPad()
            }
            .padding(.horizontal, 14)
            Rectangle().fill(p.line).frame(width: 1, height: 26)
            HStack {
                Text("Due day").font(.outfit(14, .medium))
                TextField("5", text: $dueDay)
                    .font(.barlow(19))
                    .multilineTextAlignment(.trailing)
                    .numberPad()
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 50)
        .background(p.card, in: .rect(cornerRadius: 18))
    }

    private func presetGrid(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(isPayee ? "Biller or store" : (isLoan ? "Color" : "Bank or wallet"))
                Spacer()
                if !isLoan { Text("Sets name and color").font(.outfit(12)).foregroundStyle(p.muted) }
            }
            .padding(.horizontal, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                ForEach(presets) { preset in
                    let on = pickedPreset == preset && colorHex == preset.hex
                    Button { pick(preset) } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 13)
                                .fill(Color(hex: preset.hex))
                                .overlay(RoundedRectangle(cornerRadius: 13)
                                    .strokeBorder(Color.black.opacity(Color.isLight(hex: preset.hex) ? 0.12 : 0), lineWidth: 1))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if on {
                                        Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.tileText(hex: preset.hex))
                                    }
                                }
                                .padding(on ? 3 : 0)
                                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(on ? p.fg : .clear, lineWidth: 2))
                            Text(isLoan ? "" : preset.name)
                                .font(.outfit(11, .semibold))
                                .foregroundStyle(p.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 14).padding(.horizontal, 10)
            .background(p.card, in: .rect(cornerRadius: 18))
        }
    }

    /// Plain colors (gold, silver, white, card finishes). Changes only the tile color, keeps the name.
    private func colorGrid(_ p: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Color")
                Spacer()
                Text("Keeps the name").font(.outfit(12)).foregroundStyle(p.muted)
            }
            .padding(.horizontal, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                ForEach(BankPreset.cardColors) { c in
                    let on = colorHex == c.hex
                    Button { colorHex = c.hex } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 13)
                                .fill(Color(hex: c.hex))
                                .overlay(
                                    LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .topLeading, endPoint: .center)
                                        .clipShape(.rect(cornerRadius: 13))
                                )
                                .overlay(RoundedRectangle(cornerRadius: 13)
                                    .strokeBorder(Color.black.opacity(Color.isLight(hex: c.hex) ? 0.12 : 0), lineWidth: 1))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if on {
                                        Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.tileText(hex: c.hex))
                                    }
                                }
                                .padding(on ? 3 : 0)
                                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(on ? p.fg : .clear, lineWidth: 2))
                            Text(c.name)
                                .font(.outfit(11, .semibold))
                                .foregroundStyle(p.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(c.name)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 14).padding(.horizontal, 10)
            .background(p.card, in: .rect(cornerRadius: 18))
        }
    }

    // MARK: Actions

    private func pick(_ preset: BankPreset) {
        if isLoan {
            pickedPreset = preset
            colorHex = preset.hex
            return
        }
        let typedOwnName = !name.isEmpty && !(BankPreset.all + BankPreset.payees).contains { $0.name == name }
        pickedPreset = preset
        colorHex = preset.hex
        if !typedOwnName { name = preset.name }
    }

    private func save() {
        guard canSave else { return }
        let account: Account
        if let editing {
            account = editing
        } else {
            account = Account(name: "", colorHex: colorHex)
            account.sortOrder = (accounts.map(\.sortOrder).max() ?? 0) + 1
            context.insert(account)
        }
        account.name = name.trimmingCharacters(in: .whitespaces)
        account.colorHex = colorHex
        account.isPayee = isPayee
        account.isLoan = isLoan
        if isLoan {
            account.owner = nil
            account.last4 = ""
            account.kind = .debit
            account.openingCentavos = signedOpening
            account.creditLimitCentavos = nil
            account.dueDay = nil
        } else if isPayee {
            account.owner = nil
            account.last4 = ""
            account.kind = .debit
            account.openingCentavos = 0
            account.creditLimitCentavos = nil
            account.dueDay = nil
        } else {
            account.owner = selectedOwner
            account.last4 = last4
            account.kind = kind
            account.openingCentavos = signedOpening
            if kind == .credit {
                account.creditLimitCentavos = Int(limit.filter(\.isNumber)).map { $0 * 100 }
                account.dueDay = Int(dueDay.filter(\.isNumber)).flatMap { (1...31).contains($0) ? $0 : nil }
            } else {
                account.creditLimitCentavos = nil
                account.dueDay = nil
            }
        }
        dismiss()
    }

    /// Fills the form from the account being edited.
    private func load(_ a: Account) {
        let t: AccountType = a.isLoan ? .loan : (a.isPayee ? .payee : .bank)
        if t != type {
            skipTypeReset = true
            type = t
        }
        theyOwe = a.openingCentavos >= 0
        selectedOwner = a.owner
        kind = a.kind
        name = a.name
        last4 = a.last4
        colorHex = a.colorHex
        pickedPreset = a.isLoan ? BankPreset.loanColors.first { $0.hex == a.colorHex }
            : (a.isPayee ? BankPreset.payees : BankPreset.all).first { $0.name == a.name && $0.hex == a.colorHex }
        opening = a.openingCentavos == 0 ? "" : EntryView.sanitize(Self.plain(abs(a.openingCentavos)))
        limit = a.creditLimitCentavos.map { String($0 / 100) } ?? ""
        dueDay = a.dueDay.map(String.init) ?? ""
    }

    /// "1250" or "1250.5" for a text field, no grouping.
    private static func plain(_ centavos: Int) -> String {
        centavos % 100 == 0 ? String(centavos / 100) : String(format: "%.2f", Double(centavos) / 100)
    }

}
