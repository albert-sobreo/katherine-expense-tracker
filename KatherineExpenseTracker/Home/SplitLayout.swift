import SwiftUI
import SwiftData

/// What the right side shows on a wide iPad window.
enum DetailRoute: Hashable {
    case entries(Date)
    case analytics(Date)
    case account(PersistentIdentifier)
    case loans
}

extension EnvironmentValues {
    /// Set on a wide iPad window: opens a screen on the right side instead of in a sheet.
    @Entry var openDetail: ((DetailRoute) -> Void)? = nil
    /// What the right side shows now, so Home can highlight it.
    @Entry var detailRoute: DetailRoute? = nil
    /// True for a screen shown on the right side: it has no close button.
    @Entry var inSplitDetail = false
}

/// Wide windows (iPad full screen or a big split): Home on the left, the picked screen on the right.
/// Narrow windows (iPhone, iPad Slide Over or a small split) look exactly like the iPhone app.
struct AdaptiveRoot: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.colorScheme) private var scheme
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @State private var route: DetailRoute = .entries(AdaptiveRoot.startOfMonth(.now))

    /// Narrower than this and the two panes get cramped, so it falls back to the phone layout.
    private static let splitMinWidth: CGFloat = 700

    static func startOfMonth(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    var body: some View {
        GeometryReader { geo in
            if sizeClass == .regular && geo.size.width >= Self.splitMinWidth {
                split(width: geo.size.width)
            } else {
                NavigationStack { HomeView() }
            }
        }
    }

    private func split(width: CGFloat) -> some View {
        let p = Palette.of(scheme)
        let sidebar = min(430, max(360, width * 0.38))
        return HStack(spacing: 0) {
            NavigationStack { HomeView() }
                .frame(width: sidebar)
            Rectangle().fill(p.line).frame(width: 1).ignoresSafeArea()
            detail
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
                .background(p.bg)
                .environment(\.inSplitDetail, true)
                .id(route)
                .transition(.opacity)
        }
        .background(p.bg)
        .environment(\.detailRoute, route)
        .environment(\.openDetail, { (new: DetailRoute) in
            withAnimation(.easeOut(duration: 0.18)) { route = new }
        })
    }

    @ViewBuilder
    private var detail: some View {
        switch route {
        case .entries(let month):
            EntriesView(month: month)
        case .analytics(let month):
            AnalyticsView(month: month)
        case .loans:
            LoansView()
        case .account(let id):
            // A deleted account falls back to this month's entries.
            if let a = accounts.first(where: { $0.persistentModelID == id }) {
                EntriesView(account: a)
            } else {
                EntriesView(month: Self.startOfMonth(.now))
            }
        }
    }
}
