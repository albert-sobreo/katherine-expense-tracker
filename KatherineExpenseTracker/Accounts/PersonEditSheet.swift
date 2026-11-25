import SwiftUI
import SwiftData

/// Edit a person: rename them, drag their accounts into order, or delete them.
/// Kath's own group ("Mine") can be reordered but not renamed or deleted.
struct PersonEditSheet: View {
    let person: Person

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var name = ""
    @State private var order: [Account] = []
    @State private var confirmDelete = false
    @State private var askDiscard = false

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var originalOrder: [Account] { (person.accounts ?? []).sorted { $0.sortOrder < $1.sortOrder } }
    private var dirty: Bool {
        (!person.isMe && trimmed != person.name) || order.map(\.persistentModelID) != originalOrder.map(\.persistentModelID)
    }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") { if dirty { askDiscard = true } else { dismiss() } }
                    .buttonStyle(.plain)
                    .font(.outfit(15, .semibold))
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(p.chip, in: .capsule)
                Spacer()
                Text(person.isMe ? "Mine" : "Edit person").font(.outfit(17, .bold))
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.plain)
                    .font(.outfit(15, .bold))
                    .foregroundStyle(p.bg)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(p.fg, in: .capsule)
                    .disabled(!person.isMe && trimmed.isEmpty)
                    .opacity(!person.isMe && trimmed.isEmpty ? 0.35 : 1)
            }
            .padding(.horizontal, 16)

            if !person.isMe {
                HStack {
                    Text("Name").font(.outfit(15, .medium))
                    TextField("Name", text: $name)
                        .font(.outfit(15, .semibold))
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 16).frame(height: 52)
                .background(p.card, in: .rect(cornerRadius: 16))
                .padding(.horizontal, 16)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    SectionLabel("Accounts")
                    Spacer()
                    if order.count > 1 {
                        Text("Drag to reorder").font(.outfit(12)).foregroundStyle(p.muted)
                    }
                }
                .padding(.horizontal, 20)
                List {
                    ForEach(order) { a in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color(hex: a.colorHex))
                                .frame(width: 26, height: 26)
                            Text(a.name).font(.outfit(15, .semibold))
                            if !a.last4.isEmpty {
                                Text("•• \(a.last4)").font(.barlow(16, .medium)).foregroundStyle(p.muted)
                            }
                            Spacer()
                            Text(Money.peso(a.balanceCentavos)).font(.barlow(16)).monospacedDigit()
                        }
                        .listRowBackground(p.card)
                    }
                    .onMove { from, to in order.move(fromOffsets: from, toOffset: to) }
                    if order.isEmpty {
                        Text("No accounts yet.").font(.outfit(14)).foregroundStyle(p.muted)
                            .listRowBackground(p.card)
                    }
                }
                .scrollContentBackground(.hidden)
                #if os(iOS)
                .environment(\.editMode, .constant(.active))
                #endif
            }

            if !person.isMe {
                Button { confirmDelete = true } label: {
                    Text("Delete \(person.name)")
                        .font(.outfit(13, .semibold)).tracking(1.6).textCase(.uppercase)
                        .foregroundStyle(Color(hex: "#DC2626"))
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(p.chip, in: .rect(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .padding(.top, 20)
        .foregroundStyle(p.fg)
        .background(p.bg)
        .presentationDragIndicator(.visible)
        .onAppear {
            name = person.name
            order = originalOrder
        }
        .discardGuard(dirty: dirty, asking: $askDiscard) { dismiss() }
        .confirmationDialog("Delete \(person.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(person)
                try? context.save()
                dismiss()
            }
        } message: {
            let n = person.accounts?.count ?? 0
            Text(n == 0
                 ? "Their entries stay."
                 : "This also deletes their \(n == 1 ? "account" : "\(n) accounts"). Entries stay, but won't show those accounts.")
        }
    }

    private func save() {
        if !person.isMe, !trimmed.isEmpty { person.name = trimmed }
        // Reuse this person's existing sort numbers, handed out in the new order.
        let slots = order.map(\.sortOrder).sorted()
        for (a, slot) in zip(order, slots) { a.sortOrder = slot }
        // Equal numbers (e.g. imported accounts) would keep the order ambiguous; spread them out.
        if Set(slots).count != slots.count, let base = slots.first {
            for (i, a) in order.enumerated() { a.sortOrder = base + i }
        }
        try? context.save()
        dismiss()
    }
}
