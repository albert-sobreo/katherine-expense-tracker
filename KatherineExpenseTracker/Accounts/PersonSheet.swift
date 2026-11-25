import SwiftUI
import SwiftData

/// "New person" bottom sheet. Their accounts get their own group in every account row.
struct PersonSheet: View {
    var onAdd: (Person) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Person.sortOrder) private var people: [Person]
    @State private var name = ""
    @State private var askDiscard = false

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        let p = Palette.of(scheme)
        VStack(spacing: 18) {
            HStack {
                Button("Cancel") { if trimmed.isEmpty { dismiss() } else { askDiscard = true } }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .font(.outfit(15, .semibold))
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(p.chip, in: .capsule)
                Spacer()
                Text("New person").font(.outfit(17, .bold))
                Spacer()
                Button("Add", action: add)
                    .buttonStyle(.plain)
                    .font(.outfit(15, .bold))
                    .foregroundStyle(p.bg)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(p.fg, in: .capsule)
                    .disabled(trimmed.isEmpty)
                    .opacity(trimmed.isEmpty ? 0.35 : 1)
            }
            VStack(spacing: 10) {
                Text(trimmed.first.map { String($0).uppercased() } ?? "?")
                    .font(.outfit(28, .bold))
                    .frame(width: 72, height: 72)
                    .background(p.chip, in: .circle)
                SectionLabel(trimmed.isEmpty ? "New group" : "\(trimmed)'s accounts")
            }
            HStack {
                Text("Name").font(.outfit(15, .medium))
                TextField("e.g. Papa", text: $name)
                    .font(.outfit(15, .semibold))
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .onSubmit(add)
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            .background(p.card, in: .rect(cornerRadius: 16))
            Text("Their accounts get their own group, after a divider, in every account row.")
                .font(.outfit(13))
                .foregroundStyle(p.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(p.fg)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .background(p.bg)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .discardGuard(dirty: !trimmed.isEmpty, asking: $askDiscard) { dismiss() }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        let person = Person(name: trimmed, sortOrder: (people.map(\.sortOrder).max() ?? 0) + 1)
        context.insert(person)
        onAdd(person)
        dismiss()
    }
}
