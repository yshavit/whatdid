// whatdid?

import Cocoa

/// A class for helping you figure out when scroll bars are or aren't visible.
/// This sets up notification handlers, so make sure to remove your reference to it when you're done!
class ScrollBarHelper {
    private let observationRef: NSKeyValueObservation
    private let notificationRef: NSObjectProtocol
    
    /// Registers a listener on the given scroller. This will also invoke the listener once, with the current settings.
    ///
    /// `scroller`: the scroller to listen to
    ///
    /// `handler`: a block that takes a boolean of whether the scroller is visible. This takes into account both the scroller's
    ///  intrinsic visibility (set by its NSScrollView) as well as `NSScroller.preferredScrollerStyle`.
    ///
    /// This init also registers a notification listener that will only be removed at deinit, so make sure to remove your reference
    /// to this instance when you're done with it.
    init(on scroller: NSScroller, handler: @escaping (Bool) -> Void) {
        observationRef = scroller.observe(
            \NSScroller.isHidden,
            changeHandler: {scroller, _ in ScrollBarHelper.handle(on: scroller, handler) })
        notificationRef = NotificationCenter.default.addObserver(
            forName: NSScroller.preferredScrollerStyleDidChangeNotification,
            object: nil,
            queue: OperationQueue.main,
            using: {_ in ScrollBarHelper.handle(on: scroller, handler)})
    }
    
    private static func handle(on scroller: NSScroller, _ handler: @escaping (Bool) -> Void) {
        let currentStyle = NSScroller.preferredScrollerStyle
        let scrollShows: Bool
        switch currentStyle {
        case .legacy:
            scrollShows = true
        case .overlay:
            scrollShows = false
        @unknown default:
            NSLog("uknown value for NSScroller.preferredScrollerStyle: \(currentStyle.rawValue)")
            scrollShows = true
        }
        handler(scrollShows && !scroller.isHidden)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(
            notificationRef,
            name: NSScroller.preferredScrollerStyleDidChangeNotification,
            object: nil)
        // observationRef cleans itself
    }
}
