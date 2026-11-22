import WidgetKit
import SwiftUI

// Home Screen widget: this month's spending, income and net balance, plus the top payees (medium).
// It reads the small snapshot the app saves in the shared App Group; it never opens the database.

private let appGroupID = "group.katherine.expensetracker"

nonisolated private struct Snapshot: Codable {
    struct Item: Codable {
        var name: String
        var colorHex: String
        var amount: Int
    }
    var month: Date
    var spent: Int
    var income: Int
    var net: Int
    var top: [Item]
    /// Monthly budget in centavos; nil or 0 when none is set.
    var budget: Int?

    static let sample = Snapshot(month: .now, spent: 1_842_000, income: 2_500_000, net: 4_825_000, top: [
        Item(name: "Meralco", colorHex: "#F26522", amount: 214_000),
        Item(name: "SM Supermarket", colorHex: "#0067B1", amount: 162_000),
        Item(name: "Grab", colorHex: "#00B14F", amount: 98_500),
    ], budget: 2_500_000)

    static func load() -> Snapshot? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: "widgetSnapshot") else { return nil }
        guard var snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return nil }
        // A new month started and the app hasn't been opened yet: this month has no spending so far.
        let cal = Calendar.current
        if !cal.isDate(snap.month, equalTo: .now, toGranularity: .month) {
            snap.month = cal.dateInterval(of: .month, for: .now)?.start ?? .now
            snap.spent = 0
            snap.income = 0
            snap.top = []
        }
        return snap
    }
}

nonisolated struct SpendEntry: TimelineEntry {
    let date: Date
    fileprivate let snapshot: Snapshot
    let isPlaceholder: Bool
}

nonisolated struct SpendProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendEntry {
        SpendEntry(date: .now, snapshot: .sample, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendEntry) -> Void) {
        completion(SpendEntry(date: .now, snapshot: Snapshot.load() ?? .sample, isPlaceholder: Snapshot.load() == nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendEntry>) -> Void) {
        let empty = Snapshot(month: .now, spent: 0, income: 0, net: 0, top: [], budget: nil)
        let entry = SpendEntry(date: .now, snapshot: Snapshot.load() ?? empty, isPlaceholder: false)
        // The app reloads the widget when numbers change; also refresh after midnight for month rollovers.
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(tomorrow)))
    }
}

// MARK: - Look

private extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        let v = UInt64(s, radix: 16) ?? 0x3F3F46
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255, opacity: 1)
    }
}

/// Mauve palette, same as the app.
private struct WidgetPalette {
    let bg, fg, muted, line: Color
    static func of(_ scheme: ColorScheme) -> WidgetPalette {
        scheme == .dark
            ? WidgetPalette(bg: Color(hex: "#1D161E"), fg: Color(hex: "#FAFAFA"), muted: Color(hex: "#A89EA9"), line: Color(hex: "#463947"))
            : WidgetPalette(bg: Color(hex: "#FFFFFF"), fg: Color(hex: "#0C090C"), muted: Color(hex: "#79697B"), line: Color(hex: "#E7E4E7"))
    }
}

private func peso(_ centavos: Int) -> String {
    let sign = centavos < 0 ? "−" : ""
    let pesos = Double(abs(centavos)) / 100
    return sign + "₱" + pesos.formatted(.number.grouping(.automatic).precision(.fractionLength(0)))
}

/// Numbers in a condensed face, close to the app's Barlow Condensed.
private func numberFont(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight).width(.condensed)
}

struct SpendWidgetView: View {
    let entry: SpendEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = WidgetPalette.of(scheme)
        let s = entry.snapshot
        Group {
            if family == .systemMedium {
                HStack(spacing: 14) {
                    summary(s, p)
                    Rectangle().fill(p.line).frame(width: 1)
                    topList(s, p)
                }
            } else {
                summary(s, p)
            }
        }
        .foregroundStyle(p.fg)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        .containerBackground(for: .widget) { p.bg }
    }

    private func summary(_ s: Snapshot, _ p: WidgetPalette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SPENT IN \(s.month.formatted(.dateTime.month(.abbreviated)).uppercased())")
                .font(.system(size: 10, weight: .semibold)).tracking(1.4)
                .foregroundStyle(p.muted)
            Text(peso(s.spent))
                .font(numberFont(34))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 2)
            if let budget = s.budget, budget > 0 {
                budgetBar(spent: s.spent, budget: budget, p)
            }
            Spacer(minLength: 6)
            row("Income", peso(s.income), p)
            row("Net", peso(s.net), p)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func budgetBar(spent: Int, budget: Int, _ p: WidgetPalette) -> some View {
        let over = spent > budget
        let rose = Color(hex: scheme == .dark ? "#FB7185" : "#F43F5E")
        let share = min(Double(spent) / Double(budget), 1)
        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(p.line)
                    Capsule().fill(over ? rose : p.fg).frame(width: geo.size.width * share)
                }
            }
            .frame(height: 4)
            Text(over ? "\(peso(spent - budget)) OVER" : "\(peso(budget - spent)) LEFT")
                .font(.system(size: 9, weight: .semibold)).tracking(1.2)
                .foregroundStyle(over ? rose : p.muted)
                .lineLimit(1)
        }
        .padding(.top, 4)
    }

    private func row(_ label: String, _ value: String, _ p: WidgetPalette) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(1.2).foregroundStyle(p.muted)
            Spacer(minLength: 4)
            Text(value).font(numberFont(15)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    private func topList(_ s: Snapshot, _ p: WidgetPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOP").font(.system(size: 10, weight: .semibold)).tracking(1.4).foregroundStyle(p.muted)
            if s.top.isEmpty {
                Text("Nothing spent yet this month.")
                    .font(.system(size: 12))
                    .foregroundStyle(p.muted)
            }
            ForEach(Array(s.top.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: item.colorHex)).frame(width: 9, height: 9)
                    Text(item.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    Text(peso(item.amount)).font(numberFont(14)).monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@main
struct KatherineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KatherineSpendWidget", provider: SpendProvider()) { entry in
            SpendWidgetView(entry: entry)
        }
        .configurationDisplayName("This month")
        .description("What you've spent this month, with income and net balance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    KatherineWidget()
} timeline: {
    SpendEntry(date: .now, snapshot: .sample, isPlaceholder: false)
}
