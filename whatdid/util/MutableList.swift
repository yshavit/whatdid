// whatdid?

class MutableList<T> {
    var list = [T]()
    
    func append(_ newElement: T) {
        list.append(newElement)
    }
    
    func asList<T2>(mapEntriesTo: (T) -> T2) -> [T2] {
        return list.map(mapEntriesTo)
    }
    
    func asList() -> [T] {
        return asList {$0}
    }
}
