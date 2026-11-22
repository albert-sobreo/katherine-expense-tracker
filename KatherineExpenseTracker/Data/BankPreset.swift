import Foundation

/// Known PH banks and e-wallets. Picking one fills in the account's name and color.
/// The colors are close approximations of each brand.
struct BankPreset: Identifiable, Hashable {
    let name: String
    let hex: String
    var id: String { name }

    static let all: [BankPreset] = [
        .init(name: "GCash", hex: "#007DFE"), .init(name: "Maya", hex: "#00D26A"),
        .init(name: "BDO", hex: "#0033A0"), .init(name: "BPI", hex: "#B11116"),
        .init(name: "Metrobank", hex: "#1546A0"), .init(name: "Landbank", hex: "#00843D"),
        .init(name: "PNB", hex: "#002D72"), .init(name: "UnionBank", hex: "#FF8000"),
        .init(name: "Security Bank", hex: "#00A0DF"), .init(name: "China Bank", hex: "#D71920"),
        .init(name: "RCBC", hex: "#0B4EA2"), .init(name: "GoTyme", hex: "#00B2A9"),
        .init(name: "SeaBank", hex: "#F15A22"), .init(name: "ShopeePay", hex: "#EE4D2D"),
        .init(name: "Coins.ph", hex: "#1E5BF6"), .init(name: "Cash", hex: "#3F3F46"),
    ]

    /// Common PH billers, stores and income sources for payees.
    static let payees: [BankPreset] = [
        .init(name: "Meralco", hex: "#F26522"), .init(name: "Maynilad", hex: "#0072BC"),
        .init(name: "Manila Water", hex: "#00A9E0"), .init(name: "PLDT", hex: "#E4002B"),
        .init(name: "Globe", hex: "#0057B8"), .init(name: "Smart", hex: "#00A651"),
        .init(name: "Converge", hex: "#6A2C91"), .init(name: "Grab", hex: "#00B14F"),
        .init(name: "Foodpanda", hex: "#D70F64"), .init(name: "Shopee", hex: "#EE4D2D"),
        .init(name: "Lazada", hex: "#0F146D"), .init(name: "SM", hex: "#0067B1"),
        .init(name: "7-Eleven", hex: "#008163"), .init(name: "Mercury Drug", hex: "#E31B23"),
        .init(name: "Salary", hex: "#44403C"), .init(name: "Other", hex: "#3F3F46"),
    ]

    /// Tile colors for loans. Names are only ids; the loan is named after the person.
    static let loanColors: [BankPreset] = [
        .init(name: "Mauve", hex: "#6B5B6E"), .init(name: "Rose", hex: "#9F1239"),
        .init(name: "Amber", hex: "#B45309"), .init(name: "Teal", hex: "#0F766E"),
        .init(name: "Blue", hex: "#1D4ED8"), .init(name: "Violet", hex: "#6D28D9"),
        .init(name: "Pink", hex: "#BE185D"), .init(name: "Slate", hex: "#3F3F46"),
    ]
}
