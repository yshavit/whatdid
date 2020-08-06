// whatdid?

import Cocoa

@propertyWrapper struct Atomic<T> : CustomStringConvertible {
    private let lock = NSLock()
    private var value : T

    init(wrappedValue: T) {
        self.value = wrappedValue
    }

    var wrappedValue: T {
        get {
            let local : T
            lock.lock()
            local = value
            lock.unlock()
            return local
        }
        set(value) {
            _ = getAndSet(value)
        }
    }
    
    var description: String {
        let valueStr = String(reflecting: wrappedValue)
        return "Atomic<\(valueStr)>"
    }
    
    mutating func getAndSet(_ newValue: T) -> T {
        return mapUnsafe {_ in newValue}
    }

    /// Modifies the current value, and returns it
    mutating func modifyInPlace(_ block: (inout T) -> Void) {
        mapUnsafe {curr in
            block(&curr)
            return curr
        }
    }
    
    /// Maps the old value to a new one, and returns the old one
    @discardableResult mutating func map(_ map: (T) -> T) -> T {
        return mapUnsafe {curr in
            map(curr) // "map" can't modify curr, so we know the mapUnsafe return value is the unchanged old value
        }
    }

    /// Performs a map, and returns the old value
    @discardableResult private mutating func mapUnsafe(_ map: (inout T) -> T) -> T {
        lock.lock()
        let oldValue = value
        let newValue = map(&value)
        self.value = newValue
        lock.unlock()
        return oldValue
    }
}
