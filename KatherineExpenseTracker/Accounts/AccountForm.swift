import SwiftUI
import SwiftData

/// "New account": whose account, Debit or Credit, name, last 4, and a bank or wallet preset
/// that fills in the name and color. "+ Person" opens the New person sheet.
struct AccountForm: View {
    /// Pre-selected owner, e.g. Kath's own group. Nil makes the person pick.
    var owner: Person?

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
    @State private var dueDay = ""
    @State private var showPersonSheet = false

    private var canSave: Bool {
        selectedOwner != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 0) {
            header(p)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ownerRow(p)
                    kindSwitch(p)
                    nameRow(p)
                    if kind == .credit { creditRow(p) }
                    presetGrid(p)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(p.fg)
        .background(p.bg)
        .onAppear { if selectedOwner == nil { selectedOwner = owner } }
        .sheet(isPresented: $showPersonSheet) {
            PersonSheet { selectedOwner = $0 }
        }
    }

    // MARK: Sections

    private func header(_ p: Palette) -> some View {
        HStack {
            Button("Cancel") { dismiss() }
                .buttonStyle(.plain)
                .font(.outfit(15, .semibold))
                .padding(.horizontal, 14).frame(height: 34)
                .background(p.chip, in: .capsule)
            Spacer()
            Text("New account").font(.outfit(17, .bold))
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

    private func nameRow(_ p: Palette) -> some View {
        HStack(spacing: 12) {
            AccountTile(name: name.isEmpty ? "Name" : name, last4: last4, colorHex: colorHex,
                        selected: true, width: 110, height: 100)
            VStack(spacing: 0) {
                HStack {
                    Text("Name").font(.outfit(14, .medium))
                    TextField("BDO Savings", text: $name)
                        .font(.outfit(15, .semibold))
                        .multilineTextAlignment(.trailing)
                }
                .frame(maxHeight: .infinity)
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
            .padding(.horizontal, 14)
            .frame(height: 100)
            .background(p.card, in: .rect(cornerRadius: 18))
        }
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
                SectionLabel("Bank or wallet")
                Spacer()
                Text("Sets name and color").font(.outfit(12)).foregroundStyle(p.muted)
            }
            .padding(.horizontal, 4)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                ForEach(BankPreset.all) { preset in
                    let on = pickedPreset == preset
                    Button { pick(preset) } label: {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 13)
                                .fill(Color(hex: preset.hex))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if on {
                                        Image(systemName: "checkmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                    }
                                }
                                .padding(on ? 3 : 0)
                                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(on ? p.fg : .clear, lineWidth: 2))
                            Text(preset.name)
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

    // MARK: Actions

    private func pick(_ preset: BankPreset) {
        let typedOwnName = !name.isEmpty && !BankPreset.all.contains { $0.name == name }
        pickedPreset = preset
        colorHex = preset.hex
        if !typedOwnName { name = preset.name }
    }

    private func save() {
        guard canSave, let owner = selectedOwner else { return }
        let account = Account(name: name.trimmingCharacters(in: .whitespaces), last4: last4,
                              colorHex: colorHex, kind: kind, owner: owner)
        account.sortOrder = (accounts.map(\.sortOrder).max() ?? 0) + 1
        if kind == .credit {
            if let pesos = Int(limit.filter(\.isNumber)) { account.creditLimitCentavos = pesos * 100 }
            if let day = Int(dueDay.filter(\.isNumber)), (1...31).contains(day) { account.dueDay = day }
        }
        context.insert(account)
        dismiss()
    }
}
