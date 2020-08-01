// whatdid?

class MutableDict<K: Hashable, V> {
    private var value = [K: V]()
    
    subscript(_ key: K) -> V? {
        get {
            return value[key]
        }
        set (newValue) {
            value[key] = newValue
        }
    }
    
    func asDictionary<V2>(mapValuesTo: (V) -> V2) -> [K: V2] {
        return value.mapValues(mapValuesTo)
    }
    
    func asDictionary() -> [K: V] {
        return asDictionary {$0}
    }
}
