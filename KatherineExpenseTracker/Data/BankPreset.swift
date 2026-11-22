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
}
