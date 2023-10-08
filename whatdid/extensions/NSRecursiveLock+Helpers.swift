// whatdid?

import Foundation

extension NSRecursiveLock {
    
    func synchronized(_ block: () -> Void) {
        let _ = synchronizedGet {() -> Bool in
            block()
            return false
        }
    }
    
    func synchronizedGet<T>(_ block: () -> T) -> T {
        lock()
        defer { unlock() }
        return block()
    }
}
