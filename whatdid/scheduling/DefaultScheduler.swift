// whatdid?

import Cocoa

struct DefaultScheduler {
    
    #if UI_TEST
    static let instance = ManualTickScheduler()
    #else
    static let instance: Scheduler = SystemClockScheduler()
    #endif
    
    private init() {
        // nothing
    }
}
