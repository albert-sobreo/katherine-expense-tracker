import SwiftUI

/// Swipe a row left to reveal a red Delete button; swipe further or tap it to delete.
/// Works inside a plain ScrollView (no List needed), so the spreadsheet keeps its pinned header and total.
/// A tap runs `onTap`, but never right after a swipe, and a tap on an open row just closes it.
struct SwipeToDelete<Content: View>: View {
    var onDelete: () -> Void
    var onTap: () -> Void = {}
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var start: CGFloat = 0
    /// True from the first sideways move until shortly after the finger lifts, so the lift isn't read as a tap.
    @State private var swiping = false
    private let reveal: CGFloat = 84

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive) {
                withAnimation(.easeOut(duration: 0.2)) { offset = 0 }
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: max(reveal, -offset))
                    .frame(maxHeight: .infinity)
                    .background(Color(hex: "#DC2626"))
            }
            .buttonStyle(.plain)
            .opacity(offset < 0 ? 1 : 0)
            .accessibilityLabel("Delete")

            content
                .contentShape(.rect)
                .onTapGesture {
                    guard !swiping else { return }
                    if offset != 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
                        start = 0
                    } else {
                        onTap()
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onTap() }
                .offset(x: offset)
        }
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { v in
                    // Only horizontal drags; vertical ones are left to the scroll view.
                    guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
                    swiping = true
                    offset = min(0, start + v.translation.width)
                }
                .onEnded { v in
                    let full = offset < -reveal * 2.2
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        offset = full ? 0 : (offset < -reveal / 2 ? -reveal : 0)
                    }
                    start = full ? 0 : offset
                    if full { onDelete() }
                    if swiping {
                        Task {
                            try? await Task.sleep(for: .milliseconds(250))
                            swiping = false
                        }
                    }
                }
        )
        .accessibilityAction(named: "Delete", onDelete)
    }
}
