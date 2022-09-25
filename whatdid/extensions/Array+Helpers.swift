// whatdid?

extension Array where Element: Hashable {
    func distinct() -> Set<Element> {
        return Set(self)
    }
}
