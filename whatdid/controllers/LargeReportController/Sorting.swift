// whatdid?

import Cocoa

struct SortInfo<T: SortOrder & Equatable>: Equatable {
    var key: T
    var ascending: Bool

    init(key: T, ascending: Bool) {
        self.key = key
        self.ascending = ascending
    }

    init?(parsedFrom input: String, to enumInit: (String) -> T?) {
        if let prefix = input.dropping(suffix: "Ascending"), let enumVal = T(rawValue: prefix) {
            key = enumVal
            ascending = true
        } else if let prefix = input.dropping(suffix: "Descending"), let enumVal = T(rawValue: prefix) {
            key = enumVal
            ascending = false
        } else {
            wdlog(.warn, "invalid SortInfo: %@", input)
            return nil
        }
    }

    var sortingFunction: (T.SortedElement, T.SortedElement) -> Bool {
        key.sortOrder(ascending: ascending)
    }

    var asString: String {
        String(describing: key) + (ascending ? "Ascending" : "Descending")
    }

    static func == (lhs: SortInfo<T>, rhs: SortInfo<T>) -> Bool {
        lhs.key == rhs.key && lhs.ascending == rhs.ascending
    }
}

protocol SortOrder {
    associatedtype SortedElement

    init?(rawValue: String)
    func sortOrder(ascending: Bool) -> (SortedElement, SortedElement) -> Bool
}

func createOrdering<T, C: Comparable>(using property: @escaping (T) -> C, ascending: Bool) -> (T, T) -> Bool {
    if ascending {
        return { property($0) < property($1) }
    } else {
        return { property($0) > property($1) }
    }
}

func createOrdering<T>(lowercased property: @escaping (T) -> String, ascending: Bool) -> (T, T) -> Bool {
    createOrdering(using: {property($0).lowercased()}, ascending: ascending)
}
