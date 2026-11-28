import Foundation
import SwiftData

/// An expense another app asks to log, opened from a link like
/// `katherine://log?payee=Meralco&amount=2450.75&date=2026-11-25&method=GCash&note=Ref%20123`.
/// DueDay sends one after a bill is marked paid. Nothing is saved until you tap Save.
struct LogRequest: Identifiable, Equatable {
    let id = UUID()
    var payee: String
    var centavos: Int
    /// The link had an amount, even if it's zero (a bill that came out free).
    var hasAmount: Bool
    var date: Date
    /// How it was paid, as the other app names it ("GCash", "Bank transfer", "BPI Card"...).
    var method: String
    var note: String

    init?(url: URL) {
        guard url.scheme?.lowercased() == "katherine",
              (url.host ?? "").lowercased() == "log" || url.path.lowercased().hasSuffix("log"),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return nil }
        func value(_ key: String) -> String {
            (items.first { $0.name == key }?.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        payee = value("payee")
        method = value("method")
        note = value("note")
        let parsed = Decimal(string: value("amount").replacingOccurrences(of: ",", with: ""),
                             locale: Locale(identifier: "en_US_POSIX"))
        hasAmount = parsed != nil
        let amount = parsed ?? 0
        centavos = Int((NSDecimalNumber(decimal: amount).doubleValue * 100).rounded())
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        date = f.date(from: value("date")).map { Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: $0) ?? $0 } ?? .now
        if payee.isEmpty && !hasAmount { return nil }
    }
}

/// Loose name matching between apps that spell things differently ("MERALCO", "Meralco bill", "Globe At Home").
enum NameMatch {
    static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .joined(separator: " ")
    }

    /// 0...1, how alike two names are. Below about 0.6 they're different things.
    static func score(_ a: String, _ b: String) -> Double {
        let x = normalize(a), y = normalize(b)
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        if x == y { return 1 }
        let xs = x.replacingOccurrences(of: " ", with: ""), ys = y.replacingOccurrences(of: " ", with: "")
        if xs == ys { return 0.98 }
        if min(xs.count, ys.count) >= 3, xs.contains(ys) || ys.contains(xs) { return 0.85 }
        let wa = Set(x.split(separator: " ")), wb = Set(y.split(separator: " "))
        let words = Double(wa.intersection(wb).count) / Double(wa.union(wb).count)
        let edits = 1 - Double(distance(Array(xs), Array(ys))) / Double(max(xs.count, ys.count))
        return max(words * 0.9, edits * 0.9)
    }

    /// The closest name at or above `threshold`.
    static func best<T>(_ name: String, in items: [T], threshold: Double = 0.6, by key: (T) -> String) -> T? {
        guard !normalize(name).isEmpty else { return nil }
        return items
            .map { ($0, score(name, key($0))) }
            .filter { $0.1 >= threshold }
            .max { $0.1 < $1.1 }?.0
    }

    private static func distance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return prev[b.count]
    }
}

/// Which of your accounts a payment method from another app means, learned from what you save.
/// Stored on this device as JSON in @AppStorage("linkedMethods").
enum LinkedMethods {
    static let storageKey = "linkedMethods"

    static func load(_ json: String) -> [String: PersistentIdentifier] {
        guard let data = json.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: PersistentIdentifier].self, from: data)) ?? [:]
    }

    static func saving(_ id: PersistentIdentifier, for method: String, into json: String) -> String {
        let key = NameMatch.normalize(method)
        guard !key.isEmpty else { return json }
        var all = load(json)
        all[key] = id
        guard let data = try? JSONEncoder().encode(all), let text = String(data: data, encoding: .utf8) else { return json }
        return text
    }

    /// The account to pay from: the one picked last time for this method, else the closest name,
    /// else the only credit card for "Credit card". Nil leaves the usual default.
    static func account(for method: String, in mine: [Account], json: String) -> Account? {
        let key = NameMatch.normalize(method)
        guard !key.isEmpty else { return nil }
        if let id = load(json)[key], let a = mine.first(where: { $0.persistentModelID == id }) { return a }
        if let a = NameMatch.best(method, in: mine, threshold: 0.7, by: \.name) { return a }
        if key.contains("credit") {
            let cards = mine.filter { $0.kind == .credit }
            if cards.count == 1 { return cards[0] }
        }
        return nil
    }
}
