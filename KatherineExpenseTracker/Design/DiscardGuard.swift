import SwiftUI

extension View {
    /// Keeps a form sheet from closing by accident. While `dirty`, a swipe down does nothing,
    /// and Cancel (which sets `asking`) shows "Discard changes?" before anything is thrown away.
    func discardGuard(dirty: Bool, asking: Binding<Bool>, onDiscard: @escaping () -> Void) -> some View {
        self
            .interactiveDismissDisabled(dirty)
            .confirmationDialog("Discard changes?", isPresented: asking, titleVisibility: .visible) {
                Button("Discard", role: .destructive, action: onDiscard)
                Button("Keep editing", role: .cancel) {}
            }
    }
}
