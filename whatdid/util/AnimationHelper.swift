// whatdid?

import Cocoa

struct AnimationHelper {
    private init() {}
    
    #if UI_TEST
    static var animation_factor = 0.0
    #endif
    
    static func animate(duration: TimeInterval = 0.5, change: Action, onComplete: Action? = nil) {
        let actualDuration: TimeInterval
        #if UI_TEST
        actualDuration = duration * animation_factor
        #else
        actualDuration = duration
        #endif
        if actualDuration == 0 {
            change()
            onComplete?()
        } else {
            NSAnimationContext.runAnimationGroup(
                {context in
                    context.allowsImplicitAnimation = true
                    context.duration = actualDuration
                    change()
                },
                completionHandler: onComplete)
        }
    }
}
