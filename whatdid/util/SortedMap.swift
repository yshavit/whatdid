// whatdid?

/// A sorted map backed by a sorted array.
///
/// This implementation is not as efficient as a self-balancing BST, but is simpler to implement.
/// In particular, repeated single-adds are less efficient than a bulk add: each operation is `O(n log n)` on the current
/// size of the map, meaning that `n` single additions are `O(n² log n)`.
struct SortedMap<K: Comparable, V> {
    private var list = [Entry]()
    
    var entries: [Entry] {
        return list
    }
    
    private func indexOf(highestEntryLessThanOrEqualTo key: K) -> SearchResult {
        if list.isEmpty {
            return .emptySet
        }
        if key < list[0].key {
            return .noneFound
        }
        var low = 0
        var high = list.count - 1
        // A binary search traditionally loops while `low < high`, but we want to do `<=`.
        // This means the loop will go one iteration past the point at which we know that the element doesn't exist.
        // But when it ends, `high` and `low` will be correctly inverted such that the item would be "between" them.
        while low <= high {
            let mid = (high + low) / 2
            let midVal = list[mid].key
            if key == midVal {
                return .foundAtIndex(mid)
            }
            if key > midVal {
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        // The element isn't in the set, but `low` and `high` are the two indexes that it would have been between.
        // Note that they're inverted: low > high (since that's the condition that would cause the `while` to break).
        // We want to return the lower index, which is actually `high`.
        return .foundAtIndex(high)
    }
    
    func find(highestEntryLessThanOrEqualTo needle: K) -> V? {
        switch indexOf(highestEntryLessThanOrEqualTo: needle) {
        case .noneFound, .emptySet:
            return nil
        case .foundAtIndex(let idx):
            return list[idx].value
        }
    }
    
    mutating func add(kvPairs: [(K, V)]) {
        add(entries: kvPairs.map(Entry.init))
    }
    
    mutating func add(entries: [Entry]) {
        list.append(contentsOf: entries)
        list.sort(by: {$0.key < $1.key })
        // Save a copy of the list (which is already sorted), but then clear it.
        // Then, re-add all elements as long as they're unique
        let contents = list
        list.removeAll(keepingCapacity: true)
        for elem in contents {
            if elem.key != list.last?.key {
                list.append(elem)
            }
        }
    }
    
    mutating func removeAll() {
        list.removeAll()
    }
    
    enum SearchResult: Equatable {
        case emptySet
        case noneFound
        case foundAtIndex(_ index: Int)
    }
        
    struct Entry {
        let key: K
        let value: V
    }
}
           
extension SortedMap.Entry: Equatable where V: Equatable {
    
}
