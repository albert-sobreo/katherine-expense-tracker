import SwiftUI

/// Month picker as a small sheet: ‹ 2026 › on top, the 12 months in a 4×3 grid.
/// Year arrows go back to 2000 (or the oldest entry, if older). Months with no entries are dimmed,
/// future months are disabled. Optional "All time" button (selection nil).
struct MonthPickerSheet: View {
    @Binding var selection: Date?
    /// Dates of the entries in scope, used to dim empty months and find the oldest year.
    var entryDates: [Date]
    var allowsAllTime = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var year = Calendar.current.component(.year, from: .now)

    private let cal = Calendar.current
    private var thisYear: Int { cal.component(.year, from: .now) }
    private var thisMonth: Int { cal.component(.month, from: .now) }
    /// Any year back to 2000, or further if older entries exist. Empty months are just dimmed.
    private var oldestYear: Int { min(entryDates.map { cal.component(.year, from: $0) }.min() ?? 2000, 2000) }

    /// "year-month" keys that have at least one entry.
    private var filled: Set<Int> {
        Set(entryDates.map { cal.component(.year, from: $0) * 100 + cal.component(.month, from: $0) })
    }

    var body: some View {
        let p = Palette.of(scheme)
        let keys = filled
        VStack(spacing: 16) {
            HStack {
                yearArrow("chevron.left", enabled: year > oldestYear) { year -= 1 }
                    .accessibilityLabel("Previous year")
                Spacer()
                Text(String(year)).font(.barlow(26)).monospacedDigit()
                    .contentTransition(.numericText())
                Spacer()
                yearArrow("chevron.right", enabled: year < thisYear) { year += 1 }
                    .accessibilityLabel("Next year")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(1...12, id: \.self) { m in
                    let date = cal.date(from: DateComponents(year: year, month: m, day: 1)) ?? .now
                    let future = year > thisYear || (year == thisYear && m > thisMonth)
                    let on = selection.map { cal.isDate($0, equalTo: date, toGranularity: .month) } ?? false
                    let hasEntries = keys.contains(year * 100 + m)
                    Button {
                        selection = date
                        dismiss()
                    } label: {
                        Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                            .font(.outfit(13, .semibold)).tracking(1.2)
                            .foregroundStyle(on ? p.bg : (hasEntries ? p.fg : p.muted))
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(on ? p.fg : (hasEntries ? p.card : p.chip.opacity(0.5)),
                                        in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(future)
                    .opacity(future ? 0.3 : 1)
                    .accessibilityLabel(date.formatted(.dateTime.month(.wide).year()) + (hasEntries ? "" : ", no entries"))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            if allowsAllTime {
                Button {
                    selection = nil
                    dismiss()
                } label: {
                    Text("ALL TIME")
                        .font(.outfit(13, .semibold)).tracking(1.6)
                        .foregroundStyle(selection == nil ? p.bg : p.fg)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(selection == nil ? p.fg : p.chip, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 16)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(p.fg)
        .background(p.bg)
        .presentationDetents([.height(allowsAllTime ? 360 : 300)])
        .presentationDragIndicator(.visible)
        .onAppear { year = selection.map { cal.component(.year, from: $0) } ?? thisYear }
    }

    private func yearArrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.easeOut(duration: 0.15)) { action() } } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Palette.of(scheme).chip, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
    }
}
