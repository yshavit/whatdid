// whatdid?

import Cocoa

struct DefaultScheduler {
    
    #if UI_TEST
    private static let manualSchedulerWindow = ManualTickSchedulerWindow()
    #else
    private static let realScheduler: Scheduler = SystemClockScheduler()
    #endif
    
    private init() {
        // nothing
    }
    
    static var instance: Scheduler {
        #if UI_TEST
        return manualSchedulerWindow.scheduler
        #else
        return realScheduler
        #endif
    }
}
