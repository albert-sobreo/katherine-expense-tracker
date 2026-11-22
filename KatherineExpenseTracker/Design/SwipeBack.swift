#if os(iOS)
import UIKit

/// Pushed pages hide the system navigation bar to use the app's own header. iOS turns off the
/// swipe-from-the-left-edge back gesture when that happens; this turns it back on.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
#endif
