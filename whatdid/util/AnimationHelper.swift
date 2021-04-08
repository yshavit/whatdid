// whatdid?

import Cocoa

struct AnimationHelper {
    private init() {}
    
    #if UI_TEST
    static var use_animations = false
    #endif
    
    static func animate(duration: TimeInterval, change: Action, onComplete: Action? = nil) {
        #if UI_TEST
        if use_animations {
            reallyAnimate(duration: duration, change: change, onComplete: onComplete)
        } else {
            change()
            onComplete?()
        }
        #else
        reallyAnimate(duration: duration, change: change, onComplete: onComplete)
        #endif
    }
    
    private static func reallyAnimate(duration: TimeInterval, change: Action, onComplete: Action? = nil) {
        NSAnimationContext.runAnimationGroup(
            {context in
                context.allowsImplicitAnimation = true
                context.duration = duration
                change()
            },
            completionHandler: onComplete)
    }
}
